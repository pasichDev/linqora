import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../data/enums/type_messages_ws.dart';
import '../../data/models/discovered_service.dart';
import '../../data/models/metrics.dart';
import '../../data/models/ws_message.dart';
import '../../data/providers/mdns_provider.dart';
import '../../data/providers/websocket_provider.dart';
import '../../utils/device_info.dart';

enum MDnsStatus { connecting, connected, cancel, ws }

class DeviceHomeController extends GetxController {
  final MDnsProvider mdnsProvider;
  final WebSocketProvider webSocketProvider;

  DeviceHomeController({
    required this.mdnsProvider,
    required this.webSocketProvider,
  });

  final RxBool isConnected = false.obs;
  final Rx<MDnsStatus> mdnsConnectingStatus = MDnsStatus.connecting.obs;

  final RxList<DiscoveredService> devices = <DiscoveredService>[].obs;
  final RxString selectedDeviceIp = ''.obs;
  final RxString deviceCode = '0'.obs;
  final RxInt selectedMenuIndex = (-1).obs;

  // Масиви для зберігання останніх 20 метрик
  final RxList<double> temperatures = <double>[].obs;
  final RxList<double> cpuLoads = <double>[].obs;
  final RxList<double> ramUsages = <double>[].obs;

  // Поточні значення метрик
  final Rx<CPUMetrics?> currentCPUMetrics = Rx<CPUMetrics?>(null);
  final Rx<RAMMetrics?> currentRAMMetrics = Rx<RAMMetrics?>(null);

  // Максимальна кількість записів для зберігання
  static const int maxMetricsCount = 20;

  // Методи для отримання даних у UI
  List<double> getTemperatures() => temperatures.toList();
  List<double> getCPULoads() => cpuLoads.toList();
  List<double> getRAMUsages() => ramUsages.toList();

  CPUMetrics? getCurrentCPUMetrics() => currentCPUMetrics.value;
  RAMMetrics? getCurrentRAMMetrics() => currentRAMMetrics.value;

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
    super.onClose();
  }

  void startDiscovery() async {
    mdnsConnectingStatus.value = MDnsStatus.connecting;
    var mErrorDiscovery = false;
    mdnsProvider.onConnected = () {
      mdnsConnectingStatus.value = MDnsStatus.connected;
    };
    mdnsProvider.onEmpty = () {
      mErrorDiscovery = false;
      mdnsConnectingStatus.value = MDnsStatus.cancel;
    };
    try {
      devices.value = await mdnsProvider.discoverDevices(deviceCode.value);
      if (devices.isNotEmpty && devices[0].address != null) {
        connectToDevice(devices[0].address!, int.parse(devices[0].port!));
      } else {
        mdnsConnectingStatus.value = MDnsStatus.cancel;
        mErrorDiscovery = true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Помилка при пошуку пристроїв: $e');
      }
      mdnsConnectingStatus.value = MDnsStatus.cancel;
      mErrorDiscovery = true;
    }

    if (mErrorDiscovery) {
      Get.back(result: {'status': 'cancel'});
      Get.snackbar(
        'Пристрій недоступний',
        'Встановити з\'єднання з пристроєм не вдалося',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> connectToDevice(String ip, int port) async {
    selectedDeviceIp.value = ip;

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
          'Пристрій недоступний',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    };

    await webSocketProvider.connect(ip, port, deviceCode.value);

    final authenticated = await authenticate();
    if (!authenticated) {
      if (kDebugMode) {
        print('Авторизація не вдалася');
      }
      await webSocketProvider.disconnect();
      return;
    }

    print('Успішно авторизовано!');
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
          webSocketProvider.setAuthenticated(true);
          var systemInfo = data['authInfomation'] as Map<String, dynamic>;
          if (kDebugMode) {
            print(
              'Авторизація успішна. \n Інформація про систему: $systemInfo',
            );
          }

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
          if (kDebugMode) {
            print('Таймаут авторизації');
          }
        }
      });

      return await completer.future;
    } catch (e) {
      if (kDebugMode) {
        print('Помилка під час авторизації: $e');
      }
      return false;
    }
  }

  void joinMetricsRoom() async {
    webSocketProvider.registerHandler('metrics', (data) {
      final metricsData = data['data'] as Map<String, dynamic>;

      final cpuData = metricsData['cpuMetrics'] as Map<String, dynamic>;
      final ramData = metricsData['ramMetrics'] as Map<String, dynamic>;

      // Оновлюємо поточні метрики
      currentCPUMetrics.value = CPUMetrics.fromJson(cpuData);
      currentRAMMetrics.value = RAMMetrics.fromJson(ramData);

      // Оновлюємо масиви для графіків
      _updateMetricsArrays(
        currentCPUMetrics.value!.temperature,
        currentCPUMetrics.value!.loadPercent,
        currentRAMMetrics.value!.usage,
      );
    });

    // Приєднуємося до кімнати метрик
    await webSocketProvider.joinRoom('metrics');
  }

  void leaveMetricsRoom() async {
    webSocketProvider.leaveRoom('metrics');
    webSocketProvider.removeHandler('metrics');

    currentCPUMetrics.value = null;
    currentRAMMetrics.value = null;
  }

  void joinMouseRoom() async {
    webSocketProvider.registerHandler('control', (data) {});

    // Приєднуємося до кімнати метрик
    await webSocketProvider.joinRoom('control');
  }

  void cancelConnection() {
    mdnsConnectingStatus.value = MDnsStatus.cancel;
    Get.back(result: {'status': 'cancel'});
  }

  void selectMenuItem(int index) {
    selectedMenuIndex.value = index;
  }

  void _updateMetricsArrays(
    double temperature,
    double cpuLoad,
    double ramUsage,
  ) {
    // Оновлення масиву температур
    if (temperatures.length >= maxMetricsCount) {
      temperatures.removeAt(0);
    }
    temperatures.add(temperature);

    // Оновлення масиву навантаження CPU
    if (cpuLoads.length >= maxMetricsCount) {
      cpuLoads.removeAt(0);
    }
    cpuLoads.add(cpuLoad);

    // Оновлення масиву використання RAM
    if (ramUsages.length >= maxMetricsCount) {
      ramUsages.removeAt(0);
    }
    ramUsages.add(ramUsage);
  }
}
