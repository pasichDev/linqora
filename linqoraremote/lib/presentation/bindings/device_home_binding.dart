import 'package:get/get.dart';
import 'package:linqoraremote/presentation/controllers/clipboard_controller.dart';
import 'package:linqoraremote/presentation/controllers/display_controller.dart';
import 'package:linqoraremote/presentation/controllers/keyboard_controller.dart';
import 'package:linqoraremote/presentation/controllers/platform_caps_controller.dart';
import 'package:linqoraremote/presentation/controllers/settings_controller.dart';
import 'package:linqoraremote/presentation/controllers/startup_controller.dart';

import '../../data/providers/websocket_provider.dart';
import '../controllers/device_home_controller.dart';
import '../controllers/script_controller.dart';

class DeviceHomeBinding extends Bindings {
  @override
  void dependencies() {
    var webSocketProvider = Get.put(WebSocketProvider());
    Get.put(SettingsController());
    Get.put(DeviceHomeController(webSocketProvider: webSocketProvider));
    Get.put(ScriptController(webSocketProvider: webSocketProvider));
    Get.put(PlatformCapsController(webSocketProvider: webSocketProvider));
    Get.lazyPut(() => KeyboardController(webSocketProvider: webSocketProvider));
    Get.lazyPut(() => ClipboardController(webSocketProvider: webSocketProvider));
    Get.lazyPut(() => DisplayController(webSocketProvider: webSocketProvider));
    Get.lazyPut(() => StartupController(webSocketProvider: webSocketProvider));
  }
}
