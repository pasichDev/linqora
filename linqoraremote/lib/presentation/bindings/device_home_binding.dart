import 'package:get/get.dart';

import '../../data/providers/mdns_provider.dart';
import '../../data/providers/websocket_provider.dart';
import '../controllers/device_home_controller.dart';

class DeviceHomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => MDnsProvider());
    Get.lazyPut(() => WebSocketProvider());
    Get.lazyPut(() => DeviceHomeController(
      mdnsProvider: Get.find<MDnsProvider>(),
      webSocketProvider: Get.find<WebSocketProvider>(),
    ));
  }
}
