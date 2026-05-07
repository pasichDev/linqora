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
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 10);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      title: Obx(() {
        final idx = controller.selectedMenuIndex.value;
        if (idx == -1) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                controller.hostInfo.value?.hostname ?? "LINQORA",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildTlsIndicator(context),
                  const SizedBox(width: 4),
                  Obx(() {
                    final device = controller.authDevice.value;
                    return Text(
                      device != null
                          ? "${device.address}:${device.port}"
                          : 'connecting'.tr,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    );
                  }),
                ],
              ),
            ],
          );
        }
        return Text(
          controller.appBarTitleOverride.value ?? menuOptions[idx].title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        );
      }),
      leading: IconButton(
        icon: Obx(
          () => Icon(
            controller.webSocketProvider.isConnected &&
                    controller.selectedMenuIndex.value == -1
                ? Icons.power_settings_new_rounded
                : Icons.arrow_back_ios_new_rounded,
            size: 20,
          ),
        ),
        onPressed: () async {
          if (controller.selectedMenuIndex.value != -1) {
            final back = controller.onBackPressed.value;
            if (back != null) {
              back();
            } else {
              controller.selectMenuItem(-1);
            }
            return;
          }
          if (controller.webSocketProvider.isConnected) {
            await DisconnectConfirmationDialog.show(
              onConfirm: () => {
                controller.disconnectFromDevice(isCleaned: true),
              },
              onCancel: () => Get.back(),
            );
          } else {
            controller.disconnectFromDevice(isCleaned: true);
          }
        },
      ),
      actions: [
        Obx(() {
          final idx = controller.selectedMenuIndex.value;
          if (idx >= 0 && controller.appBarActions.isNotEmpty) {
            return Row(children: controller.appBarActions.toList());
          }
          return IconButton(
            onPressed: () => Get.toNamed(AppRoutes.SETTINGS),
            icon: const Icon(Icons.tune_rounded),
          );
        }),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildTlsIndicator(BuildContext context) {
    final device = controller.authDevice.value;
    if (device == null) return const SizedBox.shrink();
    var isTLS = device.supportsTLS;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (isTLS ? Colors.green : Colors.orange).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: (isTLS ? Colors.green : Colors.orange).withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isTLS ? Icons.lock_rounded : Icons.lock_open_rounded,
            size: 10,
            color: isTLS ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            isTLS ? "SECURE" : "UNSECURE",
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              color: isTLS ? Colors.green : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }
}
