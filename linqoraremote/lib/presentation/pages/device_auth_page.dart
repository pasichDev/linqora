import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:linqoraremote/presentation/controllers/auth_controller.dart';
import 'package:linqoraremote/presentation/widgets/lx_background.dart';
import 'package:linqoraremote/presentation/widgets/lx_glass.dart';
import 'package:linqoraremote/core/themes/lx_theme.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/constants/names.dart';
import '../../core/constants/urls.dart';
import '../../core/utils/launch_url.dart';
import '../../data/models/discovered_service.dart';
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
      final discovered = authController.discoveredDevices;
      final saved = authController.savedHosts;

      if (discovered.isEmpty && saved.isEmpty) {
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

      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 10),
        children: [
          // ── Saved hosts ──────────────────────────────────────────
          if (saved.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'RECENT',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.4,
                  color: lxTextFaint,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ...saved.asMap().entries.map((e) {
              final idx = e.key;
              final device = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildDeviceRow(
                  device: device,
                  animIndex: idx,
                  trailing: GestureDetector(
                    onTap: () => authController.removeSavedHost(idx),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.close_rounded, size: 14, color: lxTextFaint),
                    ),
                  ),
                ),
              );
            }),
            if (discovered.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'DISCOVERED',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.4,
                    color: lxTextFaint,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
          // ── Discovered devices ───────────────────────────────────
          ...discovered.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildDeviceRow(device: e.value, animIndex: e.key + saved.length),
          )),
        ],
      );
    });
  }

  Widget _buildDeviceRow({
    required MdnsDevice device,
    required int animIndex,
    Widget? trailing,
  }) {
    final isTLS = device.supportsTLS;
    return LxGlass(
      onTap: () => authController.connectToDevice(device),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isTLS ? const Color(0x1A00E5FF) : const Color(0x1AFFB547),
              borderRadius: BorderRadius.circular(lxRadiusInner),
              border: Border.all(
                color: isTLS ? const Color(0x4D00E5FF) : const Color(0x4DFFB547),
              ),
            ),
            child: Icon(
              isTLS ? Icons.computer_rounded : Icons.warning_amber_rounded,
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
                  style: const TextStyle(fontSize: 12, color: lxTextDim),
                ),
              ],
            ),
          ),
          trailing ??
              const Icon(Icons.chevron_right_rounded, size: 18, color: lxTextGhost),
        ],
      ),
    ).animate().fadeIn(delay: (animIndex * 80).ms).slideX(begin: 0.15);
  }

  void _showQrScanner() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _QrScanSheet(authController: authController),
    );
  }

  void _showManualConnect() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ManualConnectSheet(authController: authController),
    );
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
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Secondary connect methods
            Row(
              children: [
                Expanded(
                  child: LxGlass(
                    onTap: _showQrScanner,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_scanner_rounded,
                            size: 16, color: lxAccent),
                        SizedBox(width: 6),
                        Text(
                          'SCAN QR',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: lxText,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: LxGlass(
                    onTap: _showManualConnect,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.keyboard_rounded,
                            size: 16, color: lxAmber),
                        SizedBox(width: 6),
                        Text(
                          'MANUAL',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: lxText,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.3),
            const SizedBox(height: 10),
            // Primary auto-discover button
            SizedBox(
              width: double.infinity,
              child: LxGlass(
                accent: true,
                onTap: authController.startDiscovery,
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.radar_rounded, size: 18, color: lxAccent),
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
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
          ],
        );
      }),
    );
  }
}

// ─── QR scanner bottom sheet ─────────────────────────────────────────────────

class _QrScanSheet extends StatefulWidget {
  final AuthController authController;
  const _QrScanSheet({required this.authController});
  @override
  State<_QrScanSheet> createState() => _QrScanSheetState();
}

class _QrScanSheetState extends State<_QrScanSheet> {
  final _scanCtrl = MobileScannerController();
  bool _handled = false;

  void _onDetect(BarcodeCapture cap) {
    if (_handled) return;
    final raw = cap.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;
    final uri = Uri.tryParse(raw);
    if (uri == null || !['linqora', 'linqoras'].contains(uri.scheme)) return;
    _handled = true;
    final ip = uri.host;
    final port = uri.hasPort ? uri.port.toString() : '8070';
    // linqora:// = TLS on (host default), linqoras:// same treatment
    const tls = true;
    _scanCtrl.dispose();
    if (mounted) Navigator.of(context).pop();
    widget.authController.connectToDeviceByIp(ip, port, tls: tls);
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: lxBg,
        border: Border(top: BorderSide(color: lxHairline)),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(lxRadiusModal)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: lxTextGhost,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.qr_code_scanner_rounded, size: 18, color: lxAccent),
                SizedBox(width: 10),
                Text(
                  'Scan QR Code',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: lxText,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'Open LinqoraHost on your PC and tap the QR icon in the GUI window.',
              style: TextStyle(fontSize: 13, color: lxTextDim),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(lxRadiusCard),
                child: MobileScanner(
                  controller: _scanCtrl,
                  onDetect: _onDetect,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Manual IP entry bottom sheet ────────────────────────────────────────────

class _ManualConnectSheet extends StatefulWidget {
  final AuthController authController;
  const _ManualConnectSheet({required this.authController});
  @override
  State<_ManualConnectSheet> createState() => _ManualConnectSheetState();
}

class _ManualConnectSheetState extends State<_ManualConnectSheet> {
  final _ipCtrl   = TextEditingController();
  final _portCtrl = TextEditingController(text: '8070');
  bool _tls = true;

  @override
  void dispose() {
    _ipCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  void _connect() {
    final ip = _ipCtrl.text.trim();
    if (ip.isEmpty) return;
    final port =
        _portCtrl.text.trim().isEmpty ? '8070' : _portCtrl.text.trim();
    Navigator.of(context).pop();
    widget.authController.connectToDeviceByIp(ip, port, tls: _tls);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        decoration: BoxDecoration(
          color: lxBg,
          border: Border(top: BorderSide(color: lxHairline)),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(lxRadiusModal),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: lxTextGhost,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Row(
              children: [
                Icon(Icons.keyboard_rounded, size: 18, color: lxAmber),
                SizedBox(width: 10),
                Text(
                  'Connect Manually',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: lxText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _LxTextField(
              controller: _ipCtrl,
              label: 'IP ADDRESS',
              hint: '192.168.1.100',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            _LxTextField(
              controller: _portCtrl,
              label: 'PORT',
              hint: '8070',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            LxGlass(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded,
                      size: 16, color: lxTextDim),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Secure connection (TLS)',
                      style: TextStyle(fontSize: 13, color: lxText),
                    ),
                  ),
                  Switch(
                    value: _tls,
                    onChanged: (v) => setState(() => _tls = v),
                    activeThumbColor: lxAccent,
                    activeTrackColor: const Color(0x4D00E5FF),
                    inactiveThumbColor: lxTextDim,
                    inactiveTrackColor: lxTextGhost,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: LxGlass(
                accent: true,
                onTap: _connect,
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: const Text(
                  'CONNECT',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: lxAccent,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Reusable styled text field ───────────────────────────────────────────────

class _LxTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final TextInputType? keyboardType;

  const _LxTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 1.2,
            color: lxTextFaint,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        LxGlass(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(color: lxText, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: lxTextGhost, fontSize: 15),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}
