import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/themes/lx_theme.dart';
import '../../data/providers/websocket_provider.dart';
import '../controllers/process_controller.dart';
import 'lx_glass.dart';
import 'lx_header.dart';

class ProcessView extends StatefulWidget {
  const ProcessView({super.key});

  @override
  State<ProcessView> createState() => _ProcessViewState();
}

class _ProcessViewState extends State<ProcessView> {
  late final ProcessController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(
      ProcessController(webSocketProvider: Get.find<WebSocketProvider>()),
    );
  }

  @override
  void dispose() {
    if (Get.isRegistered<ProcessController>()) Get.delete<ProcessController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LxHeader(
          title: 'Processes',
          action: Obx(
            () => Row(
              children: [
                _sortChip('CPU', ProcessSort.cpu, _ctrl),
                const SizedBox(width: 6),
                _sortChip('RAM', ProcessSort.ram, _ctrl),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _ctrl.fetchProcesses,
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
              ],
            ),
          ),
        ),
        Expanded(
          child: Obx(() {
            if (_ctrl.isLoading.value && _ctrl.processes.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: lxAccent, strokeWidth: 2),
              );
            }
            final list = _ctrl.sorted;
            if (list.isEmpty) {
              return const Center(
                child: Text('No processes', style: TextStyle(color: lxTextDim)),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              itemCount: list.length,
              itemBuilder: (_, i) => _ProcessTile(info: list[i], ctrl: _ctrl),
            );
          }),
        ),
      ],
    );
  }

  Widget _sortChip(String label, ProcessSort value, ProcessController ctrl) {
    return Obx(() {
      final active = ctrl.sort.value == value;
      return GestureDetector(
        onTap: () => ctrl.sort.value = value,
        child: LxGlass(
          accent: active,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          borderRadius: BorderRadius.circular(10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: active ? lxAccent : lxTextDim,
            ),
          ),
        ),
      );
    });
  }
}

class _ProcessTile extends StatelessWidget {
  final ProcessInfo info;
  final ProcessController ctrl;

  const _ProcessTile({required this.info, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final cpuStr = info.cpu > 0 ? '${info.cpu.toStringAsFixed(1)}%' : '0%';
    final isHot = info.cpu > 20;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: LxGlass(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: lxGlass2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  Icons.memory_rounded,
                  size: 14,
                  color: isHot ? lxAmber : lxTextDim,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: lxText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'PID ${info.pid} · ${info.rssFormatted}',
                    style: const TextStyle(fontSize: 11, color: lxTextDim),
                  ),
                ],
              ),
            ),
            Text(
              cpuStr,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isHot ? lxAmber : lxText,
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => _confirmKill(context, info, ctrl),
              child: LxGlass(
                padding: const EdgeInsets.all(6),
                borderRadius: BorderRadius.circular(8),
                child: const Icon(Icons.close_rounded, size: 14, color: lxRed),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmKill(BuildContext context, ProcessInfo info, ProcessController ctrl) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: lxSurface,
        title: const Text(
          'Kill process?',
          style: TextStyle(color: lxText, fontSize: 16),
        ),
        content: Text(
          '${info.name} (PID ${info.pid}) will be terminated.',
          style: const TextStyle(color: lxTextDim, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel', style: TextStyle(color: lxTextDim)),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              ctrl.killProcess(info.pid);
            },
            child: const Text('Kill', style: TextStyle(color: lxRed)),
          ),
        ],
      ),
    );
  }
}
