import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/presentation/dashboard_items.dart';
import 'package:linqoraremote/routes/app_routes.dart';

import '../controllers/device_home_controller.dart';
import 'dialogs/dialog_cancel_connect_device.dart';

class AppBarHomePage extends StatelessWidget implements PreferredSizeWidget {
  final DeviceHomeController controller = Get.find<DeviceHomeController>();

  AppBarHomePage({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Obx(
        () => Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              controller.selectedMenuIndex.value == -1
                  ? controller.hostInfo.value?.hostname ?? ""
                  : menuOptions[controller.selectedMenuIndex.value].title,
              style: Get.textTheme.titleMedium!.copyWith(
                color: Get.theme.colorScheme.onPrimaryContainer,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildTlsIndicator(context),

                Obx(() {
                  final device = controller.authDevice.value;
                  return Text(
                    device != null
                        ? "${device.address}:${device.port}"
                        : 'connecting'.tr,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha(204),
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
      elevation: 7,
      leading: IconButton(
        icon: Obx(
          () => Icon(
            controller.webSocketProvider.isConnected &&
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
          if (controller.webSocketProvider.isConnected &&
              controller.selectedMenuIndex.value == -1) {
            await DisconnectConfirmationDialog.show(
              onConfirm:
                  () => {controller.disconnectFromDevice(isCleaned: true)},
              onCancel: () => {},
            );
          } else {
            controller.disconnectFromDevice(isCleaned: true);
          }
        },
      ),
      actions: [
        IconButton(
          onPressed: () => Get.toNamed(AppRoutes.SETTINGS),
          icon: Icon(Icons.settings),
        ),
      ],
    );
  }

  Widget _buildTlsIndicator(BuildContext context) {
    var isTLS = controller.authDevice.value!.supportsTLS;
    return Row(
      children: [
        Icon(
          isTLS ? Icons.lock_outlined : Icons.block_sharp,
          size: 12,
          color:
              isTLS
                  ? Get.theme.colorScheme.primary
                  : Get.theme.colorScheme.errorContainer,
        ),
        SizedBox(width: 2),
        Text(
          isTLS ? "(TSL)" : "(Non-TSL)",
          style: Get.textTheme.labelSmall!.copyWith(
            color:
                isTLS
                    ? Get.theme.colorScheme.primary
                    : Get.theme.colorScheme.errorContainer,
          ),
        ),
        SizedBox(width: 2),
      ],
    );
  }
}
