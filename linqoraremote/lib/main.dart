import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:linqoraremote/core/themes/theme.dart';
import 'package:linqoraremote/presentation/bindings/device_auth_binding.dart';
import 'package:linqoraremote/presentation/bindings/device_home_binding.dart';
import 'package:linqoraremote/presentation/bindings/settings_binding.dart';
import 'package:linqoraremote/presentation/bindings/ws_host_binding.dart';
import 'package:linqoraremote/presentation/controllers/settings_controller.dart';
import 'package:linqoraremote/presentation/pages/device_auth_page.dart';
import 'package:linqoraremote/presentation/pages/device_home_page.dart';
import 'package:linqoraremote/presentation/pages/settings_page.dart';
import 'package:linqoraremote/routes/app_routes.dart';

import 'data/models/ws_host_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(WsHostModelAdapter());

  WsHostBinding().dependencies();

  await GetStorage.init('settings');

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final settingsController = Get.put(SettingsController());

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => GetMaterialApp(
        title: 'Linqora Remote',
        debugShowCheckedModeBanner: false,
        theme: MaterialTheme.lightTheme,
        darkTheme: MaterialTheme.darkTheme,
        themeMode: settingsController.themeMode.value,
        initialRoute: AppRoutes.DEVICE_AUTH,

        getPages: [
          GetPage(
            name: AppRoutes.DEVICE_AUTH,
            page: () => const DeviceAuthPage(),
            binding: DeviceAuthBinding(),
          ),
          GetPage(
            name: AppRoutes.DEVICE_HOME,
            page: () => const DeviceHomePage(),
            binding: DeviceHomeBinding(),
          ),
          GetPage(
            name: AppRoutes.SETTINGS,
            page: () => const SettingsPage(),
            binding: SettingsBinding(),
          ),
        ],
      ),
    );
  }
}
