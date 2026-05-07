import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:linqoraremote/presentation/controllers/auth_controller.dart';
import 'package:linqoraremote/presentation/widgets/lx_background.dart';
import 'package:linqoraremote/presentation/widgets/lx_glass.dart';
import 'package:linqoraremote/core/themes/lx_theme.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../../core/constants/names.dart';
import '../../core/constants/urls.dart';
import '../../core/utils/launch_url.dart';
import '../../routes/app_routes.dart';

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
    return LxBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _buildHeader(),
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

  Widget _buildHeader() {
    return Row(
      children: [
        const Text(
          'LINQORA',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.0,
            color: lxText,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => Get.toNamed(AppRoutes.SETTINGS),
          child: LxGlass(
            borderRadius: BorderRadius.circular(12),
            child: const SizedBox(
              width: 38,
              height: 38,
              child: Icon(
                Icons.settings_outlined,
                size: 18,
                color: lxTextDim,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoWifi() {
    return Center(
      child: LxGlass(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 64, color: lxRed)
                .animate(onPlay: (c) => c.repeat())
                .shimmer(duration: const Duration(seconds: 2)),
            const SizedBox(height: 24),
            Text(
              'wifi_no_connection'.tr,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: lxText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'reconnect_to_wifi_please'.tr,
              style: const TextStyle(fontSize: 14, color: lxTextDim),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQ() {
    return Row(
      children: [
        Expanded(
          child: _buildLxButton(
            onTap: () => launchUrlHandler(howItWorks),
            icon: Icons.help_outline_rounded,
            label: 'how_does_work'.tr,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildLxButton(
            onTap: () => launchUrlHandler(getLinqoraHost),
            icon: Icons.computer_rounded,
            label: appNameHost,
          ),
        ),
      ],
    );
  }

  Widget _buildLxButton({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
  }) {
    return LxGlass(
      borderRadius: BorderRadius.circular(lxRadiusTile),
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: lxAccent),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: lxText,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LoadingAnimationWidget.staggeredDotsWave(
            color: lxAccent,
            size: 64,
          ),
          const SizedBox(height: 32),
          Text(
            'search_devices_mdns'.tr,
            style: const TextStyle(
              fontSize: 14,
              letterSpacing: 1.2,
              color: lxTextDim,
              fontWeight: FontWeight.w500,
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(duration: const Duration(milliseconds: 1500)),
        ],
      ),
    );
  }

  Widget _buildConnectingView() {
    return Center(
      child: LxGlass(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LoadingAnimationWidget.inkDrop(color: lxAccent, size: 56),
            const SizedBox(height: 24),
            Obx(() => Text(
                  "${'connecting_for'.tr}\n${authController.authDevice.value?.name ?? '...'}"
                      .toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 2,
                    color: lxText,
                  ),
                  textAlign: TextAlign.center,
                )),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                authController.cancelAuth('cancel_aut_for_user'.tr);
                authController.authStatus.value = AuthStatus.scanning;
              },
              child: LxGlass(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                borderRadius: BorderRadius.circular(lxRadiusTile),
                child: Text(
                  'cancel'.tr.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: lxRed,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthPendingView() {
    return Center(
      child: LxGlass(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.security_rounded, size: 64, color: lxAccent)
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
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: lxText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'auth_request_description'.tr,
              style: const TextStyle(fontSize: 14, color: lxTextDim),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Obx(() => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x1A00E5FF),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0x4D00E5FF)),
                  ),
                  child: Text(
                    authController.authTimeoutSeconds.value.toString(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: lxAccent,
                    ),
                  ),
                )),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () =>
                  authController.cancelAuth('cancel_aut_for_user'.tr),
              child: LxGlass(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                borderRadius: BorderRadius.circular(lxRadiusTile),
                child: Text(
                  'cancel'.tr.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: lxRed,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
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
              const Icon(
                Icons.devices_other_rounded,
                size: 64,
                color: lxTextGhost,
              ),
              const SizedBox(height: 24),
              Text(
                'empty_devices_linqora'.tr,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: lxText,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'empty_devices_linqora_descriptions'.tr,
                style: const TextStyle(fontSize: 13, color: lxTextDim),
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
          final isTLS = device.supportsTLS;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: LxGlass(
              onTap: () => authController.connectToDevice(device),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isTLS
                          ? const Color(0x1A00E5FF)
                          : const Color(0x1AFFB547),
                      borderRadius: BorderRadius.circular(lxRadiusInner),
                      border: Border.all(
                        color: isTLS
                            ? const Color(0x4D00E5FF)
                            : const Color(0x4DFFB547),
                      ),
                    ),
                    child: Icon(
                      isTLS
                          ? Icons.computer_rounded
                          : Icons.warning_amber_rounded,
                      size: 18,
                      color: isTLS ? lxAccent : lxAmber,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: lxText,
                          ),
                        ),
                        Text(
                          '${device.address}:${device.port}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: lxTextDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: lxTextGhost,
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: (index * 80).ms).slideX(begin: 0.15);
        },
      );
    });
  }

  Widget _buildActionButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24, top: 8),
      child: Obx(() {
        if (authController.authStatus.value == AuthStatus.scanning ||
            authController.authStatus.value == AuthStatus.connecting ||
            authController.authStatus.value == AuthStatus.pendingAuth) {
          return const SizedBox.shrink();
        }
        return SizedBox(
          width: double.infinity,
          child: LxGlass(
            accent: true,
            onTap: authController.startDiscovery,
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.refresh_rounded, size: 18, color: lxAccent),
                const SizedBox(width: 8),
                Text(
                  'update'.tr.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: lxAccent,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
