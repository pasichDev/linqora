import 'package:get/get.dart';
import 'package:linqoraremote/presentation/pages/device_home_page.dart';

import '../presentation/bindings/device_home_binding.dart';
import '../presentation/bindings/ws_host_binding.dart';
import '../presentation/pages/device_auth_page.dart';

class AppRoutes {
  static const DEVICE_AUTH = '/deviceAuth';
  static const DEVICE_HOME = '/deviceHome';
  static const STATISTICS = '/statistics';
  static const MOUSE_CONTROL = '/mouseControl';

  static final routes = [
    GetPage(
      name: DEVICE_AUTH,
      page: () => const DeviceAuthPage(),
      binding: WsHostBinding(),
    ),
    GetPage(
      name: DEVICE_HOME,
      page: () => const DeviceHomePage(),
      binding: DeviceHomeBinding(),
    ),
  ];
}
