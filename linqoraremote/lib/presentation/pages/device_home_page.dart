import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/data/providers/websocket_provider.dart';
import 'package:linqoraremote/presentation/widgets/lx_background.dart';

import '../controllers/device_home_controller.dart';
import '../widgets/dashboard_screen.dart';
import '../widgets/dialogs/dialog_cancel_connect_device.dart';

class DeviceHomePage extends GetView<DeviceHomeController> {
  const DeviceHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final webSocketProvider = Get.find<WebSocketProvider>();

    return LxBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: WillPopScope(
            onWillPop: () async {
              if (controller.selectedMenuIndex.value != -1) {
                controller.selectMenuItem(-1);
                return false;
              }
              if (controller.webSocketProvider.isConnected &&
                  controller.selectedMenuIndex.value == -1) {
                await DisconnectConfirmationDialog.show(
                  onConfirm: () =>
                      {controller.disconnectFromDevice(isCleaned: true)},
                  onCancel: () => Get.back(),
                );
              } else {
                controller.disconnectFromDevice(isCleaned: true);
                return true;
              }
              return false;
            },
            child: Column(
              children: [
                Obx(() {
                  final state = webSocketProvider.reconnectState.value;
                  if (state == ReconnectState.reconnecting) {
                    return Container(
                      width: double.infinity,
                      color: Colors.orange.withOpacity(0.85),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Obx(
                        () => Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${'reconnecting'.tr}... (${webSocketProvider.reconnectSecondsLeft.value}s)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else if (state == ReconnectState.failed) {
                    return Container(
                      width: double.infinity,
                      color: Colors.red.shade700.withOpacity(0.9),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.wifi_off_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'connection_failed'.tr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                webSocketProvider.retryReconnect(),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              side: const BorderSide(color: Colors.white54),
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'retry'.tr,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }),
                const Expanded(child: DashboardScreen()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
