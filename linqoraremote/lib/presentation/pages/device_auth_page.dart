import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/presentation/controllers/auth_controller.dart';
import 'package:linqoraremote/presentation/widgets/app_bar.dart';
import 'package:linqoraremote/presentation/widgets/default_card.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../../core/constants/names.dart';
import '../../core/constants/urls.dart';
import '../../core/themes/styles.dart';
import '../../core/utils/lauch_url.dart';

class DeviceAuthPage extends StatefulWidget {
  const DeviceAuthPage({super.key});

  @override
  State<DeviceAuthPage> createState() => _DeviceAuthPageState();
}

class _DeviceAuthPageState extends State<DeviceAuthPage> {
  late final AuthController authController;

  @override
  void initState() {
    super.initState();
    authController = Get.find<AuthController>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarCustom(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              SizedBox(height: 10),
              Obx(() {
                return authController.authStatus.value !=
                            AuthStatus.pendingAuth &&
                        authController.authStatus.value != AuthStatus.connecting
                    ? _buildFAQ()
                    : SizedBox.shrink();
              }),

              SizedBox(height: 10),
              Expanded(
                child: Obx(() {
                  switch (authController.authStatus.value) {
                    case AuthStatus.noWifi:
                      return _buildNoWifi();
                    case AuthStatus.pendingAuth:
                      return _buildAuthPendingView();
                    case AuthStatus.connecting:
                      return _buildConnectingView();
                    case AuthStatus.scanning:
                      if (authController.discoveredDevices.isEmpty) {
                        return _buildScanningView();
                      }
                      return _buildDeviceList();
                    case AuthStatus.listDevices:
                      return _buildDeviceList();
                  }
                }),
              ),
              Obx(() {
                return authController.isWifiConnections.value
                    ? _buildActionButton()
                    : SizedBox.shrink();
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoWifi() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off,
            size: 60,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 24),
          Text('wifi_no_connection'.tr, style: Get.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'reconnect_to_wifi_please'.tr,
            style: Get.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFAQ() {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: () {
            launchUrlHandler(howItWorks);
          },
          style: AppButtonStyle.elevatedButtonStyle(context),
          icon: const Icon(Icons.remove_from_queue_rounded),
          label: Text('how_does_work'.tr),
        ),
        SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: () {
            launchUrlHandler(getLinqoraHost);
          },
          style: AppButtonStyle.elevatedButtonStyle(context),
          icon: const Icon(Icons.ac_unit),
          label: Text(appNameHost),
        ),
      ],
    );
  }

  Widget _buildScanningView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LoadingAnimationWidget.fourRotatingDots(
            color: Theme.of(context).colorScheme.onSurface,
            size: 60,
          ),
          const SizedBox(height: 24),
          Text('search_devices_mdns'.tr, style: Get.textTheme.titleMedium),
        ],
      ),
    );
  }

  Widget _buildConnectingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LoadingAnimationWidget.fourRotatingDots(
            color: Theme.of(context).colorScheme.primary,
            size: 60,
          ),
          const SizedBox(height: 24),
          Obx(
            () => Text(
              "${'connecting_for'.tr} ${authController.authDevice.value!.name}...",
              style: Get.textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: () {
              authController.cancelAuth('cancel_aut_for_user'.tr);
              setState(() {
                authController.authStatus.value = AuthStatus.scanning;
              });
            },
            style: AppButtonStyle.errorButtonStyle(context),
            child: Text('cancel'.tr),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthPendingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.security,
            size: 60,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text('auth_request_sending'.tr, style: Get.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('auth_request_description'.tr, style: Get.textTheme.bodyMedium),
          const SizedBox(height: 25),
          Obx(
            () => Text(
              'auth_request_time_pending'.trParams({
                's': authController.authTimeoutSeconds.value.toString(),
              }),
              style: Get.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed:
                () => authController.cancelAuth('cancel_aut_for_user'.tr),
            style: AppButtonStyle.errorButtonStyle(context),
            child: Text('cancel'.tr),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    return Obx(() {
      if (authController.discoveredDevices.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.devices_other,
                size: 60,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 24),
              Text(
                'empty_devices_linqora'.tr,
                style: Get.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'empty_devices_linqora_descriptions'.tr,
                style: Get.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        itemCount: authController.discoveredDevices.length,
        itemBuilder: (context, index) {
          final device = authController.discoveredDevices[index];
          return DefaultCard(
            child: ListTile(
              leading: Icon(
                Icons.computer,
                color:
                    device.supportsTLS
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.errorContainer,
              ),
              title: Text(
                device.name,
                style: Get.theme.textTheme.titleMedium?.copyWith(
                  color: Get.theme.colorScheme.onPrimaryContainer,
                ),
              ),
              subtitle: Text(
                '${device.address}:${device.port}',
                style: Get.theme.textTheme.labelMedium?.copyWith(
                  color: Get.theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              trailing: IconButton(
                icon: Icon(
                  Icons.arrow_forward,
                  color: Get.theme.colorScheme.onPrimaryContainer,
                ),
                onPressed: () => authController.connectToDevice(device),
              ),
              onTap: () => authController.connectToDevice(device),
            ),
          );
        },
      );
    });
  }

  Widget _buildActionButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Obx(() {
        if (authController.authStatus.value == AuthStatus.scanning ||
            authController.authStatus.value == AuthStatus.connecting ||
            authController.authStatus.value == AuthStatus.pendingAuth) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: 48,
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: authController.startDiscovery,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.refresh),
            label: Text(
              'update'.tr,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }),
    );
  }
}
