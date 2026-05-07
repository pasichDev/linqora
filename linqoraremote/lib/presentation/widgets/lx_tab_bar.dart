import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/themes/lx_theme.dart';

// Floating glass tab bar — 5 anchors: Hub · Monitor · Files · Console · Power
// activeIndex: 0=Hub 1=Monitor 2=Files 3=Console 4=Power
class LxTabBar extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTap;

  const LxTabBar({super.key, required this.activeIndex, required this.onTap});

  static const _tabs = [
    _Tab(label: 'Hub',     icon: Icons.hub_outlined),
    _Tab(label: 'Monitor', icon: Icons.monitor_heart_outlined),
    _Tab(label: 'Files',   icon: Icons.folder_outlined),
    _Tab(label: 'Console', icon: Icons.terminal_outlined),
    _Tab(label: 'Power',   icon: Icons.power_settings_new_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(lxRadiusTabBar),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xB20F172A), // rgba(15,23,42,0.7)
              borderRadius: BorderRadius.circular(lxRadiusTabBar),
              border: Border.all(color: lxHairline, width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 40,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_tabs.length, (i) {
                final on = i == activeIndex;
                return GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 60,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (on)
                          Positioned(
                            top: 0,
                            child: Container(
                              width: 18,
                              height: 2,
                              decoration: BoxDecoration(
                                color: lxAccent,
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: [
                                  BoxShadow(
                                    color: lxAccent.withValues(alpha: 0.8),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _tabs[i].icon,
                              size: 20,
                              color: on ? lxAccent : lxTextFaint,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _tabs[i].label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.2,
                                color: on ? lxAccent : lxTextFaint,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab {
  final String label;
  final IconData icon;
  const _Tab({required this.label, required this.icon});
}
