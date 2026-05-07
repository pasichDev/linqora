import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:linqoraremote/presentation/controllers/auth_controller.dart';
import 'package:linqoraremote/presentation/widgets/app_bar.dart';
import 'package:linqoraremote/presentation/widgets/animated_aurora_background.dart';
import 'package:linqoraremote/core/themes/lin_styles.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../../core/constants/names.dart';
import '../../core/constants/urls.dart';
import '../../core/themes/styles.dart';
import '../../core/utils/launch_url.dart';

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
    return AnimatedAuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const AppBarCustom(),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Obx(() {
                  if (authController.authStatus.value !=
                          AuthStatus.pendingAuth &&
                      authController.authStatus.value !=
                          AuthStatus.connecting) {
                    return _buildFAQ()
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: -0.2);
                  }
                  return const SizedBox.shrink();
                }),
                const SizedBox(height: 20),
                Expanded(
                  child: Obx(() {
                    Widget content;
                    switch (authController.authStatus.value) {
                      case AuthStatus.noWifi:
                        content = _buildNoWifi();
                        break;
                      case AuthStatus.pendingAuth:
                        content = _buildAuthPendingView();
                        break;
                      case AuthStatus.connecting:
                        content = _buildConnectingView();
                        break;
                      case AuthStatus.scanning:
                        if (authController.discoveredDevices.isEmpty) {
                          content = _buildScanningView();
                        } else {
                          content = _buildDeviceList();
                        }
                        break;
                      case AuthStatus.listDevices:
                        content = _buildDeviceList();
                        break;
                    }
                    return AnimatedSwitcher(duration: 500.ms, child: content);
                  }),
                ),
                Obx(() {
                  if (authController.isWifiConnections.value) {
                    return _buildActionButton()
                        .animate()
                        .fadeIn(delay: 300.ms)
                        .slideY(begin: 0.2);
                  }
                  return const SizedBox.shrink();
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoWifi() {
    return Center(
      child: LinStyles.glassMorphism(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                    Icons.wifi_off_rounded,
                    size: 80,
                    color: Theme.of(context).colorScheme.error,
                  )
                  .animate(onPlay: (c) => c.repeat())
                  .shimmer(duration: const Duration(seconds: 2)),
              const SizedBox(height: 24),
              Text(
                'wifi_no_connection'.tr,
                style: Get.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'reconnect_to_wifi_please'.tr,
                style: Get.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAQ() {
    return Row(
      children: [
        Expanded(
          child: _buildGlassButton(
            onPressed: () => launchUrlHandler(howItWorks),
            icon: Icons.help_outline_rounded,
            label: 'how_does_work'.tr,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildGlassButton(
            onPressed: () => launchUrlHandler(getLinqoraHost),
            icon: Icons.computer_rounded,
            label: appNameHost,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
  }) {
    return LinStyles.glassMorphism(
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanningView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LoadingAnimationWidget.staggeredDotsWave(
            color: Theme.of(context).colorScheme.primary,
            size: 80,
          ),
          const SizedBox(height: 32),
          Text(
                'search_devices_mdns'.tr,
                style: Get.textTheme.titleMedium?.copyWith(letterSpacing: 1.2),
              )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(duration: const Duration(milliseconds: 1500)),
        ],
      ),
    );
  }

  Widget _buildConnectingView() {
    return Center(
      child: LinStyles.glassMorphism(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LoadingAnimationWidget.inkDrop(
                color: Theme.of(context).colorScheme.primary,
                size: 60,
              ),
              const SizedBox(height: 24),
              Obx(
                () => Text(
                  "${'connecting_for'.tr}\n${authController.authDevice.value?.name ?? '...'}"
                      .toUpperCase(),
                  style: Get.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () {
                  authController.cancelAuth('cancel_aut_for_user'.tr);
                  authController.authStatus.value = AuthStatus.scanning;
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.error.withOpacity(0.5),
                  ),
                ),
                child: Text('cancel'.tr),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthPendingView() {
    return Center(
      child: LinStyles.glassMorphism(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                    Icons.security_rounded,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  )
                  .animate(onPlay: (c) => c.repeat())
                  .scale(
                    duration: const Duration(seconds: 1),
                    begin: const Offset(0.9, 0.9),
                    end: const Offset(1.1, 1.1),
                    curve: Curves.easeInOut,
                  ),
              const SizedBox(height: 24),
              Text(
                'auth_request_sending'.tr,
                style: Get.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'auth_request_description'.tr,
                style: Get.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Obx(
                () => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    authController.authTimeoutSeconds.value.toString(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () =>
                    authController.cancelAuth('cancel_aut_for_user'.tr),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.error.withOpacity(0.5),
                  ),
                ),
                child: Text('cancel'.tr),
              ),
            ],
          ),
        ),
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
                Icons.devices_other_rounded,
                size: 80,
                color: Colors.white24,
              ),
              const SizedBox(height: 24),
              Text(
                'empty_devices_linqora'.tr,
                style: Get.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'empty_devices_linqora_descriptions'.tr,
                style: Get.textTheme.bodyMedium?.copyWith(
                  color: Colors.white54,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        itemCount: authController.discoveredDevices.length,
        padding: const EdgeInsets.symmetric(vertical: 10),
        itemBuilder: (context, index) {
          final device = authController.discoveredDevices[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: LinStyles.glassMorphism(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                        (device.supportsTLS
                                ? Theme.of(context).colorScheme.primary
                                : Colors.orange)
                            .withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    device.supportsTLS
                        ? Icons.computer_rounded
                        : Icons.warning_amber_rounded,
                    color: device.supportsTLS
                        ? Theme.of(context).colorScheme.primary
                        : Colors.orange,
                  ),
                ),
                title: Text(
                  device.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                subtitle: Text(
                  '${device.address}:${device.port}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 13,
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.white.withOpacity(0.3),
                ),
                onTap: () => authController.connectToDevice(device),
              ),
            ),
          ).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.2);
        },
      );
    });
  }

  Widget _buildActionButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24, top: 16),
      child: Obx(() {
        if (authController.authStatus.value == AuthStatus.scanning ||
            authController.authStatus.value == AuthStatus.connecting ||
            authController.authStatus.value == AuthStatus.pendingAuth) {
          return const SizedBox.shrink();
        }

        return ElevatedButton.icon(
          onPressed: authController.startDiscovery,
          icon: const Icon(Icons.refresh_rounded),
          label: Text('update'.tr.toUpperCase()),
        );
      }),
    );
  }
}
