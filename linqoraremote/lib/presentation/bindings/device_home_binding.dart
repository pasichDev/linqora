import 'package:get/get.dart';
import 'package:linqoraremote/presentation/controllers/settings_controller.dart';

import '../../data/providers/websocket_provider.dart';
import '../controllers/device_home_controller.dart';

class DeviceHomeBinding extends Bindings {
  @override
  void dependencies() {
    var webSocketProvider = Get.put(WebSocketProvider());
    Get.put(DeviceHomeController(webSocketProvider: webSocketProvider));
    Get.put(SettingsController());
  }
}
