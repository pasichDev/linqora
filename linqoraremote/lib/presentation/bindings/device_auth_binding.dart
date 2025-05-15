import 'package:get/get.dart';
import 'package:linqoraremote/presentation/controllers/auth_controller.dart';

import '../../data/providers/mdns_provider.dart';
import '../../data/providers/websocket_provider.dart';

class DeviceAuthBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(AuthController(webSocketProvider: Get.put(WebSocketProvider()), mDnsProvider: Get.put(MDnsProvider())));

  }
}
