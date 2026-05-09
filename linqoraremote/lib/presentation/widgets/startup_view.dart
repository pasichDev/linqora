import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/themes/lx_theme.dart';
import '../controllers/startup_controller.dart';
import 'lx_glass.dart';
import 'lx_header.dart';

class StartupView extends StatelessWidget {
  const StartupView({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<StartupController>();
    return Column(
      children: [
        LxHeader(
          title: 'Startup Apps',
          action: GestureDetector(
            onTap: ctrl.fetchEntries,
            child: LxGlass(
              borderRadius: BorderRadius.circular(12),
              child: const SizedBox(
                width: 34,
                height: 34,
                child: Center(
                  child: Icon(Icons.refresh_rounded, size: 14, color: lxTextDim),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Obx(() {
            if (ctrl.isLoading.value && ctrl.entries.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: lxAccent, strokeWidth: 2),
              );
            }
            if (ctrl.entries.isEmpty) {
              return const Center(
                child: Text('No startup entries', style: TextStyle(color: lxTextDim)),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              itemCount: ctrl.entries.length,
              itemBuilder: (_, i) => _StartupTile(entry: ctrl.entries[i], ctrl: ctrl),
            );
          }),
        ),
      ],
    );
  }
}

class _StartupTile extends StatelessWidget {
  final StartupEntry entry;
  final StartupController ctrl;

  const _StartupTile({required this.entry, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: LxGlass(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: entry.enabled ? const Color(0x1A00E5FF) : lxGlass2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: entry.enabled ? const Color(0x4D00E5FF) : lxHairline,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.power_settings_new_rounded,
                  size: 14,
                  color: entry.enabled ? lxAccent : lxTextFaint,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: entry.enabled ? lxText : lxTextDim,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (entry.command.isNotEmpty)
                    Text(
                      entry.command,
                      style: const TextStyle(fontSize: 10, color: lxTextFaint),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                ],
              ),
            ),
            Switch(
              value: entry.enabled,
              onChanged: (v) => ctrl.toggleEntry(entry.name, v),
              activeColor: lxAccent,
              activeTrackColor: const Color(0x3300E5FF),
              inactiveThumbColor: lxTextFaint,
              inactiveTrackColor: lxGlass2,
            ),
          ],
        ),
      ),
    );
  }
}
