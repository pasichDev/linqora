import 'package:get/get.dart';

import '../../data/providers/mdns_provider.dart';
import '../../data/providers/websocket_provider.dart';
import '../controllers/device_home_controller.dart';
import '../controllers/media_controller.dart';
import '../controllers/metrics_controller.dart';

class DeviceHomeBinding extends Bindings {
  @override
  void dependencies() {
    final webSocketProvider = Get.put(WebSocketProvider());
    final mdnsProvider = Get.put(MDnsProvider());

    Get.put(
      DeviceHomeController(
        mdnsProvider: mdnsProvider,
        webSocketProvider: webSocketProvider,
      ),
    );
    Get.put(MetricsController(webSocketProvider: webSocketProvider));
    Get.put(MediaController(webSocketProvider: webSocketProvider));
  }
}
