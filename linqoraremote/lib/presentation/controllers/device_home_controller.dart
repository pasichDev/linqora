// Добавьте эти импорты
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/data/enums/type_messages_ws.dart';
import 'package:linqoraremote/data/models/discovered_service.dart';
import 'package:linqoraremote/data/models/host_system_info.dart';
import 'package:linqoraremote/data/models/ws_message.dart';
import 'package:linqoraremote/presentation/controllers/settings_controller.dart';
import 'package:linqoraremote/services/background_service.dart';

import '../../core/utils/error_handler.dart';
import '../../data/providers/websocket_provider.dart';
import '../../routes/app_routes.dart';

class DeviceHomeController extends GetxController with WidgetsBindingObserver {
  final WebSocketProvider webSocketProvider;

  DeviceHomeController({required this.webSocketProvider});

  final RxBool isConnected = false.obs;
  final RxInt selectedMenuIndex = (-1).obs;
  final RxBool isBackgroundServiceRunning = false.obs;
  final RxBool isReconnecting = false.obs;

  final RxMap deviceInfo = {}.obs;
  final Rxn<HostSystemInfo> hostInfo = Rxn<HostSystemInfo>();
  Timer? _connectionCheckTimer;
  Timer? _serviceStatusTimer;

  final Rxn<DiscoveredService> authDevice = Rxn<DiscoveredService>();

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
    _startConnectionCheck();

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
    _requestSystemInfo();
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
      if (kDebugMode) {
        print('Received system info: $data');
      }
      final newHostInfo = HostSystemInfo.fromJson(data['host_info']);
      hostInfo.value = newHostInfo;
    } catch (e) {
      showErrorSnackbar(
        'Ошибка обработки данных',
        'Не удалось обработать информацию о системе',
      );
    }
  }

  // Запуск таймера для проверки состояния соединения
  void _startConnectionCheck() {
    _connectionCheckTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      if (!webSocketProvider.isConnected) {
        _handleConnectionLost('WebSocket соединение закрыто');
        return;
      }
      try {
        webSocketProvider.sendMessage(
          WsMessage(type: TypeMessageWs.auth_check.value),
        );

        Future.delayed(Duration(seconds: 2), () {
          if (!isConnected.value && webSocketProvider.isConnected) {
            _handleConnectionLost(
              'Сервер не отвечает на запросы проверки авторизации',
            );
          }
        });
      } catch (e) {
        if (kDebugMode) {
          print('Ошибка отправки auth_check: $e');
        }
      }
    });
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
