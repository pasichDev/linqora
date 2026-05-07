import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/core/themes/lx_theme.dart';
import 'package:linqoraremote/data/providers/websocket_provider.dart';
import 'package:linqoraremote/presentation/controllers/device_home_controller.dart';
import 'package:linqoraremote/presentation/controllers/power_controller.dart';
import 'package:linqoraremote/presentation/widgets/lx_glass.dart';
import 'package:linqoraremote/presentation/widgets/lx_header.dart';

class PowerManagementView extends StatefulWidget {
  const PowerManagementView({super.key});

  @override
  State<PowerManagementView> createState() => _PowerManagementViewState();
}

class _PowerManagementViewState extends State<PowerManagementView> {
  late PowerController _powerController;

  @override
  void initState() {
    super.initState();
    _powerController = Get.put(
      PowerController(webSocketProvider: Get.find<WebSocketProvider>()),
    );
  }

  @override
  void dispose() {
    if (Get.isRegistered<PowerController>()) Get.delete<PowerController>();
    super.dispose();
  }

  String _formatUptime(int seconds) {
    if (seconds <= 0) return 'Online';
    final d = seconds ~/ 86400;
    final h = (seconds % 86400) ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (d > 0) return '${d}d ${h}h';
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final homeCtrl = Get.find<DeviceHomeController>();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      child: Obx(() {
        final info = homeCtrl.hostInfo.value;
        final uptime = info?.uptime ?? 0;
        final hostname = info?.hostname ?? 'Device';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            LxHeader(
              title: 'Power',
              eyebrow: '$hostname · uptime ${_formatUptime(uptime)}',
              showBack: false,
            ),

            // Status hero card
            LxGlass(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: lxGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: lxGreen.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.power_settings_new_rounded,
                      size: 18,
                      color: lxGreen,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'STATUS',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1,
                            color: lxTextFaint,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'System Online',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Uptime · ${_formatUptime(uptime)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: lxTextDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 2×2 action tiles
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.35,
              children: [
                _powerTile(
                  icon: Icons.power_settings_new_rounded,
                  label: 'Shutdown',
                  sub: 'Save & power off',
                  accentColor: lxRed,
                  action: 0,
                ),
                _powerTile(
                  icon: Icons.restart_alt_rounded,
                  label: 'Restart',
                  sub: 'Reboot now',
                  accentColor: lxAccent,
                  action: 1,
                ),
                _powerTile(
                  icon: Icons.dark_mode_rounded,
                  label: 'Sleep',
                  sub: 'Suspend memory',
                  accentColor: null,
                  action: 3,
                ),
                _powerTile(
                  icon: Icons.lock_outlined,
                  label: 'Lock',
                  sub: 'Lock screen',
                  accentColor: null,
                  action: 2,
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Scheduled section
            const Text(
              'SCHEDULED',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.4,
                color: lxTextFaint,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            LxGlass(
              child: Column(
                children: [
                  _scheduleRow('Auto-sleep after', '20 min idle', last: false),
                  _scheduleRow('Nightly restart', 'Disabled', last: false),
                  _scheduleRow('Energy profile', 'Balanced', last: true),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Disconnect button
            GestureDetector(
              onTap: () => homeCtrl.disconnectFromDevice(isCleaned: true),
              child: Container(
                width: double.infinity,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: lxHairline),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.logout_rounded,
                      size: 14,
                      color: lxTextDim,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Disconnect from $hostname',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: lxTextDim,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        );
      }),
    );
  }

  Widget _powerTile({
    required IconData icon,
    required String label,
    required String sub,
    Color? accentColor,
    required int action,
  }) {
    final isAccent = accentColor != null;
    final tintAlpha = isAccent ? 0.06 : 0.04;
    final borderAlpha = isAccent ? 0.28 : 0.08;

    return GestureDetector(
      onLongPress: () => _confirmPowerAction(action, label),
      onTap: action == 2 ? () => _powerController.fetchCommand(action) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(lxRadiusCard),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(lxRadiusCard),
            color: Color.fromRGBO(
              accentColor != null
                  ? (accentColor.r * 255.0).round().clamp(0, 255)
                  : 255,
              accentColor != null
                  ? (accentColor.g * 255.0).round().clamp(0, 255)
                  : 255,
              accentColor != null
                  ? (accentColor.b * 255.0).round().clamp(0, 255)
                  : 255,
              tintAlpha,
            ),
            border: Border.all(
              color: (accentColor ?? lxText).withValues(alpha: borderAlpha),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: (accentColor ?? lxText).withValues(
                    alpha: isAccent ? 0.12 : 0.06,
                  ),
                  border: Border.all(
                    color: (accentColor ?? lxText).withValues(
                      alpha: isAccent ? 0.3 : 0.12,
                    ),
                  ),
                ),
                child: Icon(icon, size: 16, color: accentColor ?? lxText),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: isAccent ? accentColor : lxText,
                    ),
                  ),
                  Text(
                    sub,
                    style: const TextStyle(fontSize: 11, color: lxTextDim),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmPowerAction(int action, String label) {
    if (action == 2) return; // lock needs no confirmation
    Get.dialog(
      AlertDialog(
        backgroundColor: lxSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(lxRadiusModal),
        ),
        title: Text(label, style: const TextStyle(color: lxText)),
        content: Text(
          'Are you sure you want to $label the computer?',
          style: const TextStyle(color: lxTextDim),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: lxTextFaint),
            ),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              _powerController.fetchCommand(action);
            },
            child: Text(
              label,
              style: TextStyle(
                color: action == 0 ? lxRed : lxAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scheduleRow(String title, String detail, {required bool last}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(
                bottom: BorderSide(color: lxHairline, width: 1),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            detail,
            style: const TextStyle(fontSize: 12, color: lxTextDim),
          ),
          const SizedBox(width: 6),
          const Icon(
            Icons.chevron_right_rounded,
            size: 11,
            color: lxTextGhost,
          ),
        ],
      ),
    );
  }
}
