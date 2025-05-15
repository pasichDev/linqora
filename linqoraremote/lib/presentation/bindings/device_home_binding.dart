import 'package:get/get.dart';

import '../../data/providers/websocket_provider.dart';
import '../controllers/device_home_controller.dart';
import '../controllers/media_controller.dart';
import '../controllers/metrics_controller.dart';

class DeviceHomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(
      DeviceHomeController(webSocketProvider: Get.put(WebSocketProvider())),
    );
    Get.put(MetricsController(webSocketProvider: Get.put(WebSocketProvider())));
    Get.put(MediaController(webSocketProvider: Get.put(WebSocketProvider())));
  }
}
