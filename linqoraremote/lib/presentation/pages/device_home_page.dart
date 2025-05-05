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
        title: Obx(
          () =>
              controller.devices.isEmpty ||
                      controller.authInformation.value == null
                  ? SizedBox()
                  : Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.authInformation.value?.hostname ?? "",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        "${controller.devices.first.address ?? ""}:${controller.devices.first.port ?? ""}",
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
        ),
        leading: IconButton(
          icon: Obx(
            () => Icon(
              controller.isConnected.value &&
                      controller.selectedMenuIndex.value == -1
                  ? Icons.close
                  : Icons.arrow_back,
            ),
          ),
          onPressed: () async {
            if (controller.selectedMenuIndex.value != -1) {
              controller.selectMenuItem(-1);
              return;
            }
            if (controller.isConnected.value &&
                controller.selectedMenuIndex.value == -1) {
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
