import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../data/models/discovered_service.dart';
import '../../data/providers/mdns_provider.dart';
import '../../data/providers/websocket_provider.dart';

enum MDnsStatus { connecting, connected, cancel, ws }

class DeviceHomeController extends GetxController {
  final MDnsProvider mdnsProvider;
  final WebSocketProvider webSocketProvider;

  DeviceHomeController({
    required this.mdnsProvider,
    required this.webSocketProvider,
  });

  final RxList<DiscoveredService> devices = <DiscoveredService>[].obs;
  final RxBool isConnected = false.obs;
  final RxString selectedDeviceIp = ''.obs;
  final RxString deviceCode = '0'.obs;
  final RxInt selectedMenuIndex = (-1).obs;
  final Rx<MDnsStatus> mdnsConnectingStatus = MDnsStatus.connecting.obs;

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
        connectToDevice(devices[0].address!);
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

  Future<void> connectToDevice(String ip) async {
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

    await webSocketProvider.connect(ip, 8070);

    final authenticated = await webSocketProvider.authenticate(
      deviceCode.value,
    );
    if (!authenticated) {
      if (kDebugMode) {
        print('Авторизація не вдалася');
      }
      await webSocketProvider.disconnect();
      return;
    }

    print('Успішно авторизовано!');

    /*
    // Реєструємо обробник для отримання метрик
    webSocketProvider.registerHandler('metrics', (data) {
      print('Отримано нові метрики: ${data['data']}');
    });

    // Приєднуємося до кімнати метрик
    await webSocketProvider.joinRoom('metrics');
    print('Приєднано до кімнат: ${webSocketProvider.joinedRooms}');


     */
    // Приєднуємося до кімнати керування
    //  await webSocketProvider.joinRoom('control');
    //  print('Приєднано до кімнат: ${webSocketProvider.joinedRooms}');
  }



  void cancelConnection() {
    mdnsConnectingStatus.value = MDnsStatus.cancel;
    Get.back(result: {'status': 'cancel'});
  }

  void selectMenuItem(int index) {
    selectedMenuIndex.value = index;
  }
}
