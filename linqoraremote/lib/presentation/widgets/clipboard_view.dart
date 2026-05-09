import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/themes/lx_theme.dart';
import '../controllers/clipboard_controller.dart';
import 'lx_glass.dart';
import 'lx_header.dart';

class ClipboardView extends StatelessWidget {
  const ClipboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<ClipboardController>();
    return Column(
      children: [
        LxHeader(
          title: 'Clipboard',
          action: LxGlass(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            borderRadius: BorderRadius.circular(10),
            onTap: ctrl.sendToHost,
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.upload_rounded, size: 13, color: lxAccent),
              SizedBox(width: 5),
              Text(
                'Send to PC',
                style: TextStyle(
                    fontSize: 11,
                    color: lxAccent,
                    fontWeight: FontWeight.w600),
              ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(sp18, 0, sp18, sp8),
          child: LxGlass(
            padding: const EdgeInsets.all(sp14),
            borderRadius: BorderRadius.circular(lxRadiusCard),
            child: Obx(() {
              final text = ctrl.hostClipboard.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Text(
                      'PC CLIPBOARD',
                      style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.2,
                          color: lxTextFaint,
                          fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    if (text.isNotEmpty)
                      GestureDetector(
                        onTap: ctrl.copyHostClipboard,
                        child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.copy_rounded,
                                  size: 12, color: lxAccent),
                              SizedBox(width: 4),
                              Text('Copy',
                                  style: TextStyle(
                                      fontSize: 11, color: lxAccent)),
                            ]),
                      ),
                  ]),
                  const SizedBox(height: sp8),
                  text.isEmpty
                      ? const Text(
                          'Waiting for PC clipboard…',
                          style:
                              TextStyle(color: lxTextGhost, fontSize: 13),
                        )
                      : Text(
                          text.length > 300
                              ? '${text.substring(0, 300)}…'
                              : text,
                          style: const TextStyle(
                              color: lxText, fontSize: 13, height: 1.5),
                        ),
                ],
              );
            }),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(sp18, sp4, sp18, sp6),
          child: Row(children: [
            Text(
              'HISTORY',
              style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  color: lxTextFaint,
                  fontWeight: FontWeight.w500),
            ),
          ]),
        ),
        Expanded(
          child: Obx(() {
            final entries = ctrl.history;
            if (entries.isEmpty) {
              return const Center(
                child: Text(
                  'No clipboard history yet.',
                  style: TextStyle(color: lxTextGhost, fontSize: 13),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(sp18, 0, sp18, 100),
              itemCount: entries.length,
              itemBuilder: (_, i) => _HistoryTile(
                entry: entries[i],
                onCopy: () => ctrl.copyHistoryEntry(entries[i].text),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final ClipEntry entry;
  final VoidCallback onCopy;
  const _HistoryTile({required this.entry, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${entry.time.hour.toString().padLeft(2, '0')}:'
        '${entry.time.minute.toString().padLeft(2, '0')}';
    final preview = entry.text.length > 120
        ? '${entry.text.substring(0, 120)}…'
        : entry.text;
    return Padding(
      padding: const EdgeInsets.only(bottom: sp6),
      child: LxGlass(
        padding:
            const EdgeInsets.symmetric(horizontal: sp14, vertical: sp10),
        child: Row(children: [
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(preview,
                  style: const TextStyle(
                      color: lxText, fontSize: 12, height: 1.4)),
              const SizedBox(height: 3),
              Text(timeStr,
                  style: const TextStyle(
                      color: lxTextFaint, fontSize: 10)),
            ],
          )),
          const SizedBox(width: sp8),
          GestureDetector(
            onTap: onCopy,
            child:
                const Icon(Icons.copy_rounded, size: 14, color: lxTextDim),
          ),
        ]),
      ),
    );
  }
}
