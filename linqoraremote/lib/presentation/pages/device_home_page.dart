import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text('Назва пристрою'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            if (controller.isConnected.value) {
              final result = await Get.dialog<bool>(
                AlertDialog(
                  title: const Text('Підтвердження'),
                  content: const Text(
                    'Ви впевнені, що хочете розірвати з\'єднання?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Get.back(result: false),
                      child: const Text('Скасувати'),
                    ),
                    TextButton(
                      onPressed: () => Get.back(result: true),
                      child: const Text('Так'),
                    ),
                  ],
                ),
              );
              if (result == true) {
                controller.cancelConnection();
              }
            } else {
              controller.cancelConnection();
            }
          },
        ),
      ),
      body: SizedBox(
        width: double.infinity,
        child: Obx(
          () =>
              controller.mdnsConnectingStatus.value == MDnsStatus.connecting ||
                      controller.mdnsConnectingStatus.value ==
                          MDnsStatus.connected
                  ? ConnectScreen()
                  : controller.isConnected.value
                  ? DashboardScreen()
                  : const Center(child: Text('Не знайдено пристроїв')),
        ),
      ),
    );
  }
}
