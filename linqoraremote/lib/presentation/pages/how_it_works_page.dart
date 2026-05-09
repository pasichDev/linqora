import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/themes/lx_theme.dart';
import '../widgets/lx_background.dart';
import '../widgets/lx_glass.dart';

class HowItWorksPage extends StatelessWidget {
  const HowItWorksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LxBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: Get.back,
                      child: LxGlass(
                        borderRadius: BorderRadius.circular(12),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(Icons.arrow_back_rounded,
                            size: 18, color: lxTextDim),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Text('How Linqora Works',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: lxText)),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _step('1', 'Install LinqoraHost',
                          'Download and run LinqoraHost on your PC. It starts a local WebSocket server on port 8070.'),
                      _step('2', 'Same Wi-Fi Network',
                          'Your phone and PC must be on the same local network. Linqora works entirely offline — no cloud required.'),
                      _step('3', 'Pair via QR or Auto-Discover',
                          'Scan the QR code shown in the LinqoraHost GUI window, or tap Auto-Discover to find your PC automatically via mDNS.'),
                      _step('4', 'Authenticate',
                          'On first connection you approve the device in the LinqoraHost console or GUI. Optionally set a shared secret for HMAC authentication.'),
                      _step('5', 'Encrypted Channel',
                          'After auth, all traffic is encrypted with AES-256-GCM. Self-signed TLS certificates are pinned on first connection.'),
                      const SizedBox(height: 24),
                      _platformSection('Windows', Icons.laptop_windows_outlined, [
                        'Run linqorahost.exe — a tray icon appears.',
                        'Enable auto-start via Settings → Startup.',
                        'Firewall: allow port 8070 on private networks.',
                        'Volume, media, keyboard, and mouse all supported natively.',
                      ]),
                      _platformSection('Linux', Icons.laptop_outlined, [
                        'Run ./linqora serve in a terminal.',
                        'Requires xdotool for keyboard/mouse, playerctl for media.',
                        'Autostart via ~/.config/autostart/linqorahost.desktop.',
                        'Brightness via xrandr (internal display only).',
                      ]),
                      _platformSection('macOS', Icons.laptop_mac_outlined, [
                        'Run ./linqora serve in Terminal.',
                        'Grant Accessibility & Screen Recording permissions when prompted.',
                        'Autostart managed via launchd (~/Library/LaunchAgents/).',
                        'Brightness via `brew install brightness` CLI.',
                      ]),
                      const SizedBox(height: 16),
                      LxGlass(
                        padding: const EdgeInsets.all(16),
                        child: const Row(children: [
                          Icon(Icons.security_rounded, color: lxAccent, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'All data stays on your local network. No accounts, no telemetry.',
                              style: TextStyle(
                                  color: lxTextDim, fontSize: 12, height: 1.5),
                            ),
                          ),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _step(String num, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: lxAccent.withValues(alpha: 0.1),
              border: Border.all(color: lxAccent.withValues(alpha: 0.4)),
            ),
            child: Center(
              child: Text(num,
                  style: const TextStyle(
                      color: lxAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: lxText)),
                const SizedBox(height: 4),
                Text(body,
                    style: const TextStyle(
                        fontSize: 12, color: lxTextDim, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _platformSection(
      String platform, IconData icon, List<String> tips) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: LxGlass(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 16, color: lxAccent),
              const SizedBox(width: 8),
              Text(platform,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: lxText)),
            ]),
            const SizedBox(height: 10),
            ...tips.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('·  ',
                          style: TextStyle(color: lxAccent, fontSize: 14)),
                      Expanded(
                        child: Text(t,
                            style: const TextStyle(
                                color: lxTextDim,
                                fontSize: 12,
                                height: 1.4)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
