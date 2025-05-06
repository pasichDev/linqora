import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/presentation/widgets/app_bar_home.dart';

import '../controllers/device_home_controller.dart';
import '../widgets/connect_screen.dart';
import '../widgets/dashboard_screen.dart';

/**
 * Якщо користувач відмінив підключення повернути на попереднє повідомлення і відобразити сповіщення снакбар
 * також якщо більше 10 сек підключення не працює повернути на попредню з помилкою
 */

class DeviceHomePage extends GetView<DeviceHomeController> {
  const DeviceHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarHomePage(),
      body: SizedBox(
        width: double.infinity,
        child: Obx(
          () =>
              controller.mdnsConnectingStatus.value == MDnsStatus.connecting ||
                      controller.mdnsConnectingStatus.value ==
                          MDnsStatus.connected ||
                      controller.mdnsConnectingStatus.value == MDnsStatus.retry
                  ? ConnectScreen()
                  : controller.isConnected.value
                  ? DashboardScreen()
                  : const Center(child: Text('Не знайдено пристроїв')),
        ),
      ),
    );
  }
}
