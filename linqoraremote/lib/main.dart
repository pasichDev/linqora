import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:linqoraremote/core/themes/theme.dart';
import 'package:linqoraremote/presentation/controllers/settings_controller.dart';
import 'package:linqoraremote/routes/app_routes.dart';

import 'core/constants/settings.dart';
import 'services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await BackgroundConnectionService.initializeService();
  } catch (e) {
    debugPrint("Error initializing background service: $e");
  }

  await GetStorage.init(SettingsConst.kSettings);

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

        getPages: AppRoutes().routes,
        defaultTransition: Transition.cupertino,
      ),
    );
  }
}
