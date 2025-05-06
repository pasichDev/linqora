import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/presentation/dashboard_items.dart';

import '../controllers/device_home_controller.dart';

class AppBarHomePage extends GetView<DeviceHomeController>
    implements PreferredSizeWidget {
  const AppBarHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
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
                      controller.selectedMenuIndex.value == -1
                          ? controller.authInformation.value?.hostname ?? ""
                          : menuOptions[controller.selectedMenuIndex.value]
                              .title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (controller.devices.value.first.supportsTLS == true) ...[
                          Icon(
                            Icons.lock_outlined,
                            size: 12,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          SizedBox(width: 2),
                          Text(
                            "(TSL)",
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          SizedBox(width: 2),
                        ],

                        Text(
                          "${controller.devices.first.address ?? ""}:${controller.devices.first.port ?? ""}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.8),
                          ),
                        ),
                      ],
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
                    onPressed: () => {Get.back(result: false)},
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
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
