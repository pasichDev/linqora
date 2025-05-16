import 'package:get/get_navigation/src/routes/get_route.dart';
import 'package:linqoraremote/presentation/bindings/device_auth_binding.dart';
import 'package:linqoraremote/presentation/bindings/device_home_binding.dart';
import 'package:linqoraremote/presentation/bindings/settings_binding.dart';
import 'package:linqoraremote/presentation/pages/device_auth_page.dart';
import 'package:linqoraremote/presentation/pages/device_home_page.dart';
import 'package:linqoraremote/presentation/pages/settings_page.dart';

class AppRoutes {
  static const DEVICE_AUTH = '/deviceAuth';
  static const DEVICE_HOME = '/deviceHome';
  static const SETTINGS = '/settings';

  var routes = [
    GetPage(
      name: DEVICE_AUTH,
      page: () => const DeviceAuthPage(),
      binding: DeviceAuthBinding(),
    ),
    GetPage(
      name: DEVICE_HOME,
      page: () => const DeviceHomePage(),
      binding: DeviceHomeBinding(),
    ),
    GetPage(
      name: SETTINGS,
      page: () => const SettingsPage(),
      binding: SettingsBinding(),
    ),
  ];
}
