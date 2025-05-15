import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/presentation/widgets/app_bar_home.dart';

import '../controllers/device_home_controller.dart';
import '../widgets/dashboard_screen.dart';
import '../widgets/dialogs/dialog_cancel_connect_device.dart';

class DeviceHomePage extends GetView<DeviceHomeController> {
  const DeviceHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (controller.selectedMenuIndex.value != -1) {
          controller.selectMenuItem(-1);
          return false;
        }
        if (controller.isConnected.value &&
            controller.selectedMenuIndex.value == -1) {
          final result = await DisconnectConfirmationDialog.show(
            onConfirm: () {
              controller.disconnectFromDevice();
            },
          );
          if (result == true) {
            controller.disconnectFromDevice();
          }
        } else {
          controller.disconnectFromDevice();
          return true;
        }
        return false;
      },

      child: Scaffold(
        appBar: AppBarHomePage(),
        body: SizedBox(width: double.infinity, child: DashboardScreen()),
      ),
    );
  }
}
