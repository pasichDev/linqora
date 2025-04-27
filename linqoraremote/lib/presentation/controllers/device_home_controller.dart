import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../data/models/discovered_service.dart';
import '../../data/providers/mdns_provider.dart';
import '../../data/providers/websocket_provider.dart';

class DeviceHomeController extends GetxController {
  final MDnsProvider mdnsProvider;
  final WebSocketProvider webSocketProvider;

  DeviceHomeController({
    required this.mdnsProvider,
    required this.webSocketProvider,
  });

  final RxList<DiscoveredService> devices = <DiscoveredService>[].obs;
  final RxBool isConnecting = true.obs;
  final RxBool isConnected = false.obs;
  final RxString selectedDeviceIp = ''.obs;
  final RxString deviceCode = '0'.obs;
  final RxInt selectedMenuIndex = (-1).obs;

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
    isConnecting.value = true;
    var mErrorDiscovery = false;

    try {
      devices.value = await mdnsProvider.discoverDevices(deviceCode.value);
      if (devices.isNotEmpty && devices[0].address != null) {
        connectToDevice(devices[0].address!);
      } else {
        isConnecting.value = false;
        mErrorDiscovery = true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Помилка при пошуку пристроїв: $e');
      }
      isConnecting.value = false;
      mErrorDiscovery = true;
    }

    if (mErrorDiscovery) {
      Get.back(result: {'status': 'cancel'});
      Get.snackbar(
        'Втрачено з\'єднання',
        'Пристрій недоступний',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void connectToDevice(String ip) {
    selectedDeviceIp.value = ip;

    webSocketProvider.onConnected = () {
      isConnected.value = true;
      isConnecting.value = false;
    };

    webSocketProvider.onDisconnected = () {
      isConnected.value = false;
      Get.back(result: {'status': 'cancel'});
      Get.snackbar(
        'Втрачено з\'єднання',
        'Пристрій недоступний',
        snackPosition: SnackPosition.BOTTOM,
      );
    };

    /* webSocketProvider.onError = (error) {
      isConnected.value = false;
      Get.snackbar('Помилка з\'єднання', 'Сталася помилка: $error');
    };

    */

    webSocketProvider.connect(ip, 8070);
  }

  void cancelConnection() {
    isConnecting.value = false;
    Get.back(result: {'status': 'cancel'});
  }

  void selectMenuItem(int index) {
    selectedMenuIndex.value = index;
  }
}
