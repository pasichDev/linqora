import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/core/themes/lx_theme.dart';
import 'package:linqoraremote/presentation/controllers/monitoring_controller.dart';
import 'package:linqoraremote/presentation/controllers/platform_caps_controller.dart';
import 'package:linqoraremote/presentation/widgets/lx_glass.dart';
import 'package:linqoraremote/presentation/widgets/lx_ring.dart';
import 'package:linqoraremote/presentation/widgets/lx_sparkline.dart';
import 'package:linqoraremote/presentation/widgets/lx_tab_bar.dart';
import 'package:linqoraremote/presentation/widgets/dialogs/dialog_cancel_connect_device.dart';

import '../controllers/device_home_controller.dart';
import '../dashboard_items.dart';
import '../../routes/app_routes.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DeviceHomeController _homeController;

  @override
  void initState() {
    super.initState();
    _homeController = Get.find<DeviceHomeController>();
  }

  @override
  void dispose() {
    if (Get.isRegistered<DeviceHomeController>()) {
      Get.delete<DeviceHomeController>();
    }
    super.dispose();
  }

  MonitoringController? get _monitoringController {
    try {
      return Get.find<MonitoringController>();
    } catch (_) {
      return null;
    }
  }

  /// Returns the filtered list of menu options based on platform capabilities.
  /// Falls back to showing all options when caps haven't loaded yet.
  List<MenuOption> get _visibleOptions {
    PlatformCapsController? caps;
    try {
      caps = Get.find<PlatformCapsController>();
    } catch (_) {}
    if (caps == null || caps.features.isEmpty) return menuOptions;
    return menuOptions.where((opt) {
      if (opt.requiredCap == null) return true;
      return caps!.has(opt.requiredCap!);
    }).toList();
  }

  // Tab index <-> menu index mapping helpers
  int _menuIndexForTab(int tab) {
    switch (tab) {
      case 1:
        return 0; // Monitor
      case 2:
        return 5; // Files
      case 3:
        return 4; // Scripts/Console
      case 4:
        return 2; // Power
      default:
        return -1; // Hub
    }
  }

  int _activeTabIndex() {
    final idx = _homeController.selectedMenuIndex.value;
    switch (idx) {
      case 0:
        return 1;
      case 5:
        return 2;
      case 4:
        return 3;
      case 2:
        return 4;
      default:
        return 0; // Hub, Media, Touchpad all show Hub tab (or hide)
    }
  }

  bool _showTabBar() {
    final idx = _homeController.selectedMenuIndex.value;
    return idx != 1 && idx != 3; // hide for Media and Touchpad
  }

  String _formatUptime(int seconds) {
    if (seconds <= 0) return 'Online';
    final d = seconds ~/ 86400;
    final h = (seconds % 86400) ~/ 3600;
    if (d > 0) return '${d}d ${h}h';
    return '${h}h';
  }

  Widget _statLabel(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: lxTextFaint,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            color: lxText,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _moduleCard({
    required IconData icon,
    required String label,
    required String sub,
    required int index,
    bool accent = false,
  }) {
    return LxGlass(
      accent: accent,
      onTap: () => _homeController.selectMenuItem(index),
      padding: const EdgeInsets.all(14),
      child: SizedBox(
        height: 96,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accent
                    ? const Color(0x1A00E5FF)
                    : lxGlass2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: accent
                      ? const Color(0x4D00E5FF)
                      : lxHairline,
                ),
              ),
              child: Icon(
                icon,
                size: 16,
                color: accent ? lxAccent : lxText,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: lxText,
                  ),
                ),
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 11,
                    color: lxTextDim,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHub() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            // --- Connection header ---
            GestureDetector(
              onTap: () => Get.toNamed(AppRoutes.PC_INFO),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CONNECTED TO',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.4,
                      color: lxTextFaint,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Obx(() => Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            _homeController.hostInfo.value?.hostname ?? 'LINQORA',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.6,
                              color: lxText,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '· ${_homeController.hostInfo.value?.kernelVersion ?? ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: lxTextDim,
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: lxTextFaint,
                          ),
                        ],
                      )),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: lxGreen,
                    boxShadow: [
                      BoxShadow(color: lxGreen, blurRadius: 6),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Online',
                  style: TextStyle(fontSize: 12, color: lxTextDim),
                ),
                const Text(' · ', style: TextStyle(color: lxTextGhost)),
                Obx(() {
                  final device = _homeController.authDevice.value;
                  return Text(
                    device != null ? device.address : '',
                    style: const TextStyle(fontSize: 12, color: lxTextDim),
                  );
                }),
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
                        size: 16,
                        color: lxTextDim,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    if (_homeController.webSocketProvider.isConnected) {
                      await DisconnectConfirmationDialog.show(
                        onConfirm: () => {
                          _homeController.disconnectFromDevice(isCleaned: true),
                        },
                        onCancel: () => Get.back(),
                      );
                    } else {
                      _homeController.disconnectFromDevice(isCleaned: true);
                    }
                  },
                  child: LxGlass(
                    borderRadius: BorderRadius.circular(12),
                    child: const SizedBox(
                      width: 38,
                      height: 38,
                      child: Icon(
                        Icons.power_settings_new_rounded,
                        size: 16,
                        color: lxTextDim,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // --- Hero stat card ---
            const SizedBox(height: 16),
            Obx(() {
              _homeController.hostInfo.value; // always reactive even when mc is null
              final mc = _monitoringController;
              final cpu = mc?.currentCPUMetrics.value;
              final ram = mc?.currentRAMMetrics.value;
              final cpuVal = cpu?.loadPercent.toDouble() ?? 0.0;
              final cpuLoads = mc?.cpuLoads.toList() ?? <int>[];
              return LxGlass(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    LxRing(
                      value: cpuVal,
                      size: 64,
                      strokeWidth: 2.5,
                      label: 'LOAD',
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PAST 60 MIN',
                            style: TextStyle(
                              fontSize: 11,
                              color: lxTextFaint,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          LxSparkline(
                            data: cpuLoads,
                            width: 170,
                            height: 36,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _statLabel(
                                'CPU',
                                cpu != null ? '${cpu.loadPercent}%' : '--%',
                              ),
                              const SizedBox(width: 14),
                              _statLabel(
                                'RAM',
                                ram != null ? '${ram.loadPercent}%' : '--%',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            // --- Modules ---
            const SizedBox(height: 14),
            const Text(
              'MODULES',
              style: TextStyle(
                fontSize: 11,
                color: lxTextFaint,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Obx(() {
              // Reading caps.features triggers a rebuild when capabilities arrive.
              PlatformCapsController? caps;
              try {
                caps = Get.find<PlatformCapsController>();
              } catch (_) {}
              caps?.features.isEmpty;

              final visible = _visibleOptions;
              final uptime = _formatUptime(
                _homeController.hostInfo.value?.uptime ?? 0,
              );

              return LayoutBuilder(
                builder: (context, constraints) {
                  final screenWidth = constraints.maxWidth;
                  const cardHeight = 96.0;
                  final cardWidth = (screenWidth - 10) / 2;
                  final ratio = cardWidth / cardHeight;

                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: ratio,
                    children: visible.map((opt) {
                      final globalIndex = menuOptions.indexOf(opt);
                      final isPower = opt.icon == Icons.energy_savings_leaf_outlined;
                      return _moduleCard(
                        icon: opt.icon,
                        label: opt.title,
                        sub: isPower ? 'Online · $uptime' : _subForOption(opt),
                        index: globalIndex,
                        accent: isPower,
                      );
                    }).toList(),
                  );
                },
              );
            }),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  String _subForOption(MenuOption opt) {
    switch (opt.icon) {
      case Icons.monitor_heart_outlined:
        return 'Live metrics';
      case Icons.volume_up:
        return 'Now playing';
      case Icons.folder_outlined:
        return 'Browse files';
      case Icons.code_rounded:
        return 'Run commands';
      case Icons.mouse_outlined:
        return 'Remote input';
      case Icons.keyboard_outlined:
        return 'Remote keyboard';
      case Icons.content_paste_outlined:
        return 'Sync clipboard';
      case Icons.brightness_medium_outlined:
        return 'Screen control';
      case Icons.memory_rounded:
        return 'Running apps';
      case Icons.power_settings_new_rounded:
        return 'Startup apps';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content
        Obx(() {
          final idx = _homeController.selectedMenuIndex.value;
          if (idx >= 0) {
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: KeyedSubtree(
                key: ValueKey(idx),
                child: menuOptions[idx].view,
              ),
            );
          }
          return _buildHub();
        }),
        // Floating tab bar
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Obx(
            () => _showTabBar()
                ? LxTabBar(
                    activeIndex: _activeTabIndex(),
                    onTap: (i) =>
                        _homeController.selectMenuItem(_menuIndexForTab(i)),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}
