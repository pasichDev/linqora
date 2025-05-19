// Добавьте эти импорты
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/data/enums/type_messages_ws.dart';
import 'package:linqoraremote/data/models/discovered_service.dart';
import 'package:linqoraremote/data/models/host_info.dart';
import 'package:linqoraremote/data/models/ws_message.dart';
import 'package:linqoraremote/presentation/controllers/settings_controller.dart';
import 'package:linqoraremote/services/background_service.dart';

import '../../core/constants/server.dart';
import '../../core/utils/error_handler.dart';
import '../../core/utils/ping.dart';
import '../../data/models/server_response.dart';
import '../../data/providers/websocket_provider.dart';
import '../../routes/app_routes.dart';

class DeviceHomeController extends GetxController with WidgetsBindingObserver {
  final WebSocketProvider webSocketProvider;

  DeviceHomeController({required this.webSocketProvider});

  final RxBool isConnected = false.obs;
  final RxInt selectedMenuIndex = (-1).obs;
  final RxBool isBackgroundServiceRunning = false.obs;
  final RxBool isReconnecting = false.obs;
  int _missedPongCount = 0;
  final latency = RxInt(0);

  final RxMap deviceInfo = {}.obs;
  final Rxn<HostSystemInfo> hostInfo = Rxn<HostSystemInfo>();
  Timer? _connectionCheckTimer;
  Timer? _serviceStatusTimer;

  final Rxn<DiscoveredService> authDevice = Rxn<DiscoveredService>();

  final List<bool> _recentPingResults = [];
  final int _slidingWindowSize = 5;


  @override
  void onInit() {
    super.onInit();

    // Регистрируем наблюдателя за жизненным циклом приложения
    WidgetsBinding.instance.addObserver(this);

    // Получаем данные устройства из аргументов
    _setupFromArguments();

    // Настраиваем обработчики WebSocket
    _setupWebSocketHandlers();

    // Запускаем таймер для проверки соединения
    _startPingMonitor();

    // Запускаем таймер для проверки статуса сервиса
    _startServiceStatusCheck();

    // Запускаем фоновый сервис, если включено в настройках
    _startBackgroundServiceIfEnabled();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    stopBackgroundService();
    _connectionCheckTimer?.cancel();
    _serviceStatusTimer?.cancel();

    webSocketProvider.removeHandler('media');
    webSocketProvider.removeHandler('host_info');

    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kDebugMode) {
      print('App lifecycle state changed: $state');
    }
    final settings = Get.find<SettingsController>();

    // Меняем режим
    bool wasBackground = settings.backgroundMode.value;
    bool isNowBackground = state == AppLifecycleState.paused;
    settings.setBackgroundMode(isNowBackground);

    // Перезапускаем PING только при изменении режима
    if (wasBackground != isNowBackground) {
      if (kDebugMode) {
        print('Режим изменился: ${isNowBackground ? "фоновый" : "активный"}');
      }
      _startPingMonitor();
    }

    switch (state) {
      case AppLifecycleState.resumed:
        // Приложение возобновлено - проверяем соединение
        checkConnectionAfterResume();
        break;
      case AppLifecycleState.inactive:
        // Приложение неактивно - возможно, скоро будет свернуто
        break;
      case AppLifecycleState.paused:
        // Приложение свернуто - проверяем, нужно ли запустить фоновый сервис

        _handleAppPaused();
        break;
      case AppLifecycleState.detached:
        // Приложение отсоединено от UI - остановить фоновый сервис
        stopBackgroundService();
        break;
      default:
        break;
    }
  }

  void _handleAppPaused() {
    if (_shouldRunBackgroundService()) {
      startBackgroundService();
    }
  }

  bool _shouldRunBackgroundService() {
    final settingsController = Get.find<SettingsController>();
    return settingsController.enableBackgroundService.value &&
        webSocketProvider.isConnected &&
        webSocketProvider.isAuthenticated;
  }

  void _setupFromArguments() {
    final args = Get.arguments;

    if (args != null && args['device'] != null) {
      if (args['device'] != null) {
        try {
          authDevice.value = DiscoveredService.fromJson(args['device']);
        } catch (e) {
          if (kDebugMode) {
            print("Error parse device data: ${args['device']}");
          }
        }
      }

      isConnected.value = webSocketProvider.isConnected;

      if (!isConnected.value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Get.back();
          Get.offAllNamed(AppRoutes.DEVICE_AUTH);
          showErrorSnackbar(
            'Ошибка соединения',
            'Соединение с устройством потеряно',
          );
        });
      }
    }
  }

  void _setupWebSocketHandlers() {
    webSocketProvider.onDisconnected = () {
      isConnected.value = false;
      Get.offAllNamed(AppRoutes.DEVICE_AUTH);
      showErrorSnackbar(
        'Соединение разорвано',
        'Соединение с устройством Linqora было прервано',
      );
    };
    webSocketProvider.registerHandler(
      TypeMessageWs.host_info.value,
      _handleSystemInfo,
    );

    // Добавляем обработчик PONG для мониторинга времени отклика
    webSocketProvider.registerHandler('pong', _handlePong);

    _requestSystemInfo();
  }

  // Обработчик PONG для измерения задержки
  void _handlePong(Map<String, dynamic> data) {
    if (_recentPingResults.isNotEmpty) {
      _recentPingResults[_recentPingResults.length - 1] = true;
    }
    _missedPongCount = 0;

    try {
      final timestamp = data['timestamp'];
      if (timestamp != null) {
        // Вычисляем задержку
        final int pingTime = int.tryParse(timestamp.toString()) ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        final rtt = now - pingTime;
        latency.value = rtt;

        if (kDebugMode && rtt > 500) {
          if (kDebugMode) {
            print('Высокая задержка сети: $rtt мс');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Ошибка обработки PONG: $e');
      }
    }
  }

  // Запускаем таймер проверки статуса фонового сервиса
  void _startServiceStatusCheck() {
    _serviceStatusTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      isBackgroundServiceRunning.value =
          await BackgroundConnectionService.isRunning();
    });
  }

  // Запуск фонового сервиса, если включено в настройках
  Future<void> _startBackgroundServiceIfEnabled() async {
    final settingsController = Get.find<SettingsController>();
    if (settingsController.enableBackgroundService.value &&
        authDevice.value != null &&
        webSocketProvider.isConnected) {
      await startBackgroundService();
    }
  }

  // Запуск фонового сервиса
  Future<void> startBackgroundService() async {
    if (authDevice.value == null) {
      if (kDebugMode) {
        print('Cannot start background service: device is null');
      }
      return;
    }

    try {
      final deviceName = authDevice.value!.name;
      final deviceAddress =
          "${authDevice.value!.address}:${authDevice.value!.port}";

      // Получаем настройки уведомлений
      final settingsController = Get.find<SettingsController>();
      //final notificationsEnabled = settingsController.enableNotifications.value;

      // Первым делом проверим, не запущен ли уже сервис
      if (await BackgroundConnectionService.isRunning()) {
        isBackgroundServiceRunning.value = true;

        if (kDebugMode) {
          print('Background service is already running');
        }
        return;
      }

      // Запускаем сервис
      final result = await BackgroundConnectionService.startService(
        deviceName,
        deviceAddress,
      );

      isBackgroundServiceRunning.value = result;

      // Показываем уведомление только если они разрешены
      if (result &&
          settingsController.notificationPermissionGranted.value &&
          settingsController.enableNotifications.value) {
        Get.snackbar(
          'Фоновая служба',
          'Служба поддержания соединения запущена',
          duration: Duration(seconds: 7),
          mainButton: TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () {
              stopBackgroundService();
              Get.closeCurrentSnackbar();
            },
            child: Text('Отключить'),
          ),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.blueGrey.shade700,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error starting background service: $e');
      }
      isBackgroundServiceRunning.value = false;

      // Показываем ошибку только если уведомления разрешены
      final settingsController = Get.find<SettingsController>();
      if (settingsController.notificationPermissionGranted.value &&
          settingsController.enableNotifications.value) {
        showErrorSnackbar('Ошибка', 'Не удалось запустить фоновую службу: $e');
      }
    }
  }

  // Остановка фонового сервиса
  Future<void> stopBackgroundService() async {
    try {
      await BackgroundConnectionService.stopService();
      isBackgroundServiceRunning.value = false;
      if (kDebugMode) {
        print('Background service stopped');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping background service: $e');
      }
    }
  }

  void checkConnectionAfterResume() {
    if (!webSocketProvider.isConnected && authDevice.value != null) {
      isReconnecting.value = true;
      webSocketProvider
          .connect(authDevice.value!)
          .then((success) {
            if (success) {
              // Восстановление успешно
              isConnected.value = true;
              isReconnecting.value = false;

              // Восстанавливаем предыдущее состояние (комнаты, авторизация)
              webSocketProvider.setAuthenticated(true);
              _requestSystemInfo();
            } else {
              isReconnecting.value = false;
              _handleConnectionLost('Не удалось восстановить подключение');
            }
          })
          .catchError((error) {
            isReconnecting.value = false;
            _handleConnectionLost('Ошибка при восстановлении: $error');
          });
    }
  }

  // Запрос информации о системе
  void _requestSystemInfo() {
    if (!isConnected.value) return;

    try {
      webSocketProvider.sendMessage(
        WsMessage(type: TypeMessageWs.host_info.value),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error requesting system info: $e');
      }
    }
  }

  // Обработчик информации о системе
  void _handleSystemInfo(Map<String, dynamic> data) {
    try {
      final response = ServerResponse<HostSystemInfo>.fromJson(
        data,
        (json) => HostSystemInfo.fromJson(json),
      );
      if (response.hasError) {
        showErrorSnackbar(
          'Ошибка получения данных',
          'Не удалось получить информацию о системе: ${response.error?.message}',
        );
        return;
      }
      hostInfo.value = response.data;
    } catch (e) {
      showErrorSnackbar(
        'Ошибка обработки данных',
        'Не удалось обработать информацию о системе',
      );
    }
  }

  // Новый метод для управления PING/PONG
  void _startPingMonitor() {
    final settings = Get.find<SettingsController>();
    _connectionCheckTimer?.cancel();

    _connectionCheckTimer = Timer.periodic(
      getCurrentPingInterval(settings.backgroundMode.value),
      (timer) {
        if (!webSocketProvider.isConnected) {
          _handleConnectionLost('WebSocket соединение закрыто');
          return;
        }

        // Проверка счетчика пропущенных PONG
        if (_missedPongCount >= maxMissedPings) {
          _handleConnectionLost('Сервер не отвечает на PING');
          if (kDebugMode) {
            print("'Сервер не отвечает на PING'");
          }
          return;
        }

        // Увеличиваем счетчик и отправляем PING
        _missedPongCount++;
        try {
          webSocketProvider.sendPing();
          if (kDebugMode) {
            print('PING отправлен. Пропущено ответов: $_missedPongCount');
          }
        } catch (e) {
          if (kDebugMode) {
            print('Ошибка отправки PING: $e');
          }
        }
      },
    );

    _connectionCheckTimer = Timer.periodic(
      getCurrentPingInterval(settings.backgroundMode.value),
          (timer) {
        if (!webSocketProvider.isConnected) {
          _handleConnectionLost('WebSocket соединение закрыто');
          return;
        }

        // Проверяем статистику в скользящем окне
        if (_recentPingResults.length >= _slidingWindowSize) {
          int failedCount = _recentPingResults.where((success) => !success).length;
          double failRate = failedCount / _recentPingResults.length;

          // Если более 70% пингов в окне не получили ответ - разрываем соединение
          if (failRate > 0.7) {
            _handleConnectionLost('Нестабильное соединение: ${(failRate * 100).toInt()}% потерянных пакетов');
            return;
          }
        }

        // Отправляем PING и добавляем ожидание в массив
        try {
          _recentPingResults.add(false);
          if (_recentPingResults.length > _slidingWindowSize) {
            _recentPingResults.removeAt(0);
          }

          final pingId = DateTime.now().millisecondsSinceEpoch.toString();
          webSocketProvider.sendPing();
        } catch (_) {
        }
      },
    );
  }

  // Обработка потери соединения
  void _handleConnectionLost(String reason) {
    if (!isConnected.value) return;

    isConnected.value = false;
    _connectionCheckTimer?.cancel();

    if (kDebugMode) {
      print('Соединение потеряно: $reason');
    }

    stopBackgroundService();

    Get.offAllNamed(AppRoutes.DEVICE_AUTH);
    showErrorSnackbar(
      'Соединение потеряно',
      'Соединение с устройством было прервано: \n$reason',
    );
  }

  // Метод для выбора пункта меню
  void selectMenuItem(int index) {
    selectedMenuIndex.value = index;
  }

  // Отключиться от устройства
  void disconnectFromDevice() {
    stopBackgroundService();
    webSocketProvider.disconnect();
    isConnected.value = false;
    Get.back(result: {'disconnectReason': true});
  }
}
