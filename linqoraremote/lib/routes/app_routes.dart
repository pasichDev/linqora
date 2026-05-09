import 'package:get/get_navigation/src/routes/get_route.dart';
import 'package:linqoraremote/presentation/bindings/device_auth_binding.dart';
import 'package:linqoraremote/presentation/bindings/device_home_binding.dart';
import 'package:linqoraremote/presentation/bindings/settings_binding.dart';
import 'package:linqoraremote/presentation/pages/device_auth_page.dart';
import 'package:linqoraremote/presentation/pages/device_home_page.dart';
import 'package:linqoraremote/presentation/pages/how_it_works_page.dart';
import 'package:linqoraremote/presentation/pages/onboarding_page.dart';
import 'package:linqoraremote/presentation/pages/pc_info_page.dart';
import 'package:linqoraremote/presentation/pages/settings_page.dart';

class AppRoutes {
  static const ONBOARDING   = '/onboarding';
  static const DEVICE_AUTH  = '/deviceAuth';
  static const DEVICE_HOME  = '/deviceHome';
  static const SETTINGS     = '/settings';
  static const PC_INFO      = '/pcInfo';
  static const HOW_IT_WORKS = '/howItWorks';

  var routes = [
    GetPage(name: ONBOARDING,   page: () => const OnboardingPage()),
    GetPage(name: HOW_IT_WORKS, page: () => const HowItWorksPage()),
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
    GetPage(
      name: PC_INFO,
      page: () => const PcInfoPage(),
    ),
  ];
}
