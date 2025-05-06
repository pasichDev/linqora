import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../data/enums/type_messages_ws.dart';
import '../../data/models/auth_response.dart';
import '../../data/models/discovered_service.dart';
import '../../data/models/metrics.dart';
import '../../data/models/ws_message.dart';
import '../../data/providers/mdns_provider.dart';
import '../../data/providers/websocket_provider.dart';
import '../../utils/device_info.dart';
import 'metrics_controller.dart';

enum MDnsStatus { connecting, connected, cancel, ws, retry }

class DeviceHomeController extends GetxController {
  final MDnsProvider mdnsProvider;
  final WebSocketProvider webSocketProvider;

  final MetricsController metricsController;

  DeviceHomeController({
    required this.mdnsProvider,
    required this.webSocketProvider,
    required this.metricsController,
  });

  final RxBool isConnected = false.obs;
  final Rx<MDnsStatus> mdnsConnectingStatus = MDnsStatus.connecting.obs;

  final RxList<DiscoveredService> devices = <DiscoveredService>[].obs;
  final RxString deviceCode = '0'.obs;
  final RxInt selectedMenuIndex = (-1).obs;

  // Інформація яку отримуємо при авторизації
  final Rx<AuthInformation?> authInformation = Rx<AuthInformation?>(null);

  // Масиви для зберігання останніх 20 метрик
  final RxList<double> temperatures = <double>[].obs;
  final RxList<double> cpuLoads = <double>[].obs;
  final RxList<double> ramUsages = <double>[].obs;

  // Поточні значення метрик
  final Rx<CPUMetrics?> currentCPUMetrics = Rx<CPUMetrics?>(null);
  final Rx<RAMMetrics?> currentRAMMetrics = Rx<RAMMetrics?>(null);

  // Максимальна кількість записів для зберігання
  static const int maxMetricsCount = 20;

  // Параметри для повторних спроб
  static const int maxRetryAttempts = 2;
  static const Duration retryDelay = Duration(seconds: 3);

  // Кількість спроб пошуку
  int _discoveryAttempts = 0;
  Timer? _retryTimer;

  @override
  void onInit() {
    super.onInit();
    var args = Get.arguments;
    if (args != null) {
      deviceCode.value = args['deviceCode'] ?? '';
    }
    startDiscovery();
  }

  @override
  void onClose() {
    webSocketProvider.close();
    _retryTimer?.cancel();

    super.onClose();
  }

  /// Починає пошук пристроїв з підтримкою повторних спроб
  void startDiscovery() async {
    _discoveryAttempts = 0;
    _performDiscovery();
  }

  /// Виконує спробу пошуку пристроїв через mDNS
  void _performDiscovery() async {
    _discoveryAttempts++;

    if (kDebugMode) {
      print('Спроба пошуку #$_discoveryAttempts');
    }

    mdnsConnectingStatus.value = MDnsStatus.connecting;
    var errorDiscovery = false;

    mdnsProvider.onConnected = () {
      mdnsConnectingStatus.value = MDnsStatus.connected;
    };

    mdnsProvider.onEmpty = () {
      errorDiscovery = true;
      mdnsConnectingStatus.value = MDnsStatus.cancel;

      // Якщо це була не остання спроба, переходимо в статус retry
      if (_discoveryAttempts < maxRetryAttempts) {
        mdnsConnectingStatus.value = MDnsStatus.retry;
      }
    };

    try {
      devices.value = await mdnsProvider.discoverDevices(deviceCode.value);

      if (devices.isNotEmpty && devices[0].address != null) {
        connectToDevice(devices.first);
      } else {
        errorDiscovery = true;
        mdnsConnectingStatus.value = MDnsStatus.cancel;

        // Якщо це була не остання спроба, переходимо в статус retry
        if (_discoveryAttempts < maxRetryAttempts) {
          mdnsConnectingStatus.value = MDnsStatus.retry;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Помилка при пошуку пристроїв (спроба #$_discoveryAttempts): $e');
      }

      errorDiscovery = true;
      mdnsConnectingStatus.value = MDnsStatus.cancel;

      // Якщо це була не остання спроба, переходимо в статус retry
      if (_discoveryAttempts < maxRetryAttempts) {
        mdnsConnectingStatus.value = MDnsStatus.retry;
      }
    }

    // Якщо була помилка і не перевищили максимальну кількість спроб
    if (errorDiscovery && _discoveryAttempts < maxRetryAttempts) {
      _scheduleRetry();
    } else if (errorDiscovery) {
      _handleDiscoveryFailure();
    }
  }

  /// Планує повторну спробу пошуку
  void _scheduleRetry() {
    if (kDebugMode) {
      print(
        'Планування повторної спроби пошуку через ${retryDelay.inSeconds} секунд',
      );
    }

    _retryTimer?.cancel();
    _retryTimer = Timer(retryDelay, () {
      if (mdnsConnectingStatus.value == MDnsStatus.retry) {
        _performDiscovery();
      }
    });
  }

  /// Обробляє остаточну невдачу пошуку після всіх спроб
  void _handleDiscoveryFailure() {
    if (kDebugMode) {
      print('Усі спроби пошуку невдалі ($maxRetryAttempts спроб)');
    }

    Get.back(result: {'status': 'cancel'});
    Get.snackbar(
      'Пристрій недоступний',
      'Встановити з\'єднання з пристроєм не вдалося після $maxRetryAttempts спроб',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  /// Запускає повторну спробу пошуку вручну
  void retryDiscovery() {
    if (_discoveryAttempts < maxRetryAttempts) {
      _performDiscovery();
    } else {
      _handleDiscoveryFailure();
    }
  }

  Future<void> connectToDevice(DiscoveredService device) async {
    webSocketProvider.onConnected = () {
      isConnected.value = true;
      mdnsConnectingStatus.value = MDnsStatus.ws;
    };

    webSocketProvider.onDisconnected = () {
      isConnected.value = false;
      if (mdnsConnectingStatus.value == MDnsStatus.ws) {
        Get.back(result: {'status': 'cancel'});
        Get.snackbar(
          'Втрачено з\'єднання',
          'LinqoraHost неактивний',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    };

    if (device.address != null && device.port != null) {
      await webSocketProvider.connect(
        device.address!,
        int.parse(device.port!),
        deviceCode.value,
      );
    } else {
      await webSocketProvider.disconnect();
      return;
    }

    final authenticated = await authenticate();
    if (!authenticated) {
      if (kDebugMode) {
        print('Авторизація не вдалася');
      }
      await webSocketProvider.disconnect();
      return;
    }

    if (kDebugMode) {
      print('Успішно авторизовано!');
    }
  }

  // Авторизація на сервері
  Future<bool> authenticate() async {
    var deviceName = await getDeviceName();
    if (!webSocketProvider.isConnected ||
        !isConnected.value ||
        mdnsConnectingStatus.value != MDnsStatus.ws) {
      if (kDebugMode) {
        print('Неможливо авторизуватися: відсутнє підключення');
      }
      return false;
    }

    final WsMessage authMessage = WsMessage(
      type: TypeMessageWs.auth.value,
      deviceCode: deviceCode.value,
    )..setField('data', {'deviceName': deviceName});

    try {
      // Реєструємо обробник відповіді на авторизацію
      final completer = Completer<bool>();

      // Тимчасовий обробник для авторизації
      webSocketProvider.registerHandler('auth_response', (data) {
        final success = data['success'] as bool;
        if (success) {
          authInformation.value = AuthResponse.fromJson(data).authInformation;

          if (kDebugMode) {
            print(
              'Авторизація успішна. \nІнформація про систему: ${authInformation.value}',
            );
          }

          webSocketProvider.setAuthenticated(true);
          webSocketProvider.joinRoom('auth');
          completer.complete(true);
        } else {
          final message = data['message'] as String;
          if (kDebugMode) {
            print('Помилка авторизації: $message');
          }
          completer.complete(false);
        }

        // Видаляємо тимчасовий обробник
        webSocketProvider.removeHandler('auth_response');
      });
      // Відправляємо повідомлення авторизації
      webSocketProvider.sendMessage(authMessage);

      Timer(Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          completer.complete(false);
          webSocketProvider.removeHandler('auth_response');
          webSocketProvider.close();
          cancelConnection();
          if (kDebugMode) {
            print('Таймаут авторизації');
          }
        }
      });

      return await completer.future;
    } catch (e) {
      webSocketProvider.close();
      cancelConnection();
      if (kDebugMode) {
        print('Помилка під час авторизації: $e');
      }
      return false;
    }
  }

  ///  Move to MouseController
  void joinMouseRoom() async {
    webSocketProvider.registerHandler('control', (data) {});

    // Приєднуємося до кімнати метрик
    await webSocketProvider.joinRoom('control');
  }

  void cancelConnection() {
    isConnected.value = false;
    mdnsConnectingStatus.value = MDnsStatus.cancel;
    Get.back(result: {'status': 'cancel'});
  }

  void selectMenuItem(int index) {
    selectedMenuIndex.value = index;
  }
}
