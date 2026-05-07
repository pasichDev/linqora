import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/data/providers/websocket_provider.dart';
import '../controllers/monitor_controller.dart';
import '../../data/models/monitor_info.dart';

class MonitorView extends StatefulWidget {
  const MonitorView({super.key});

  @override
  State<MonitorView> createState() => _MonitorViewState();
}

class _MonitorViewState extends State<MonitorView> {
  late final MonitorController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(
      MonitorController(webSocketProvider: Get.find<WebSocketProvider>()),
    );
  }

  @override
  void dispose() {
    if (Get.isRegistered<MonitorController>()) {
      Get.delete<MonitorController>();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Obx(() {
        if (_controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_controller.errorMessage.value.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.monitor, size: 48,
                    color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 12),
                Text(_controller.errorMessage.value, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _controller.fetchMonitors,
                  icon: const Icon(Icons.refresh),
                  label: Text('retry'.tr),
                ),
              ],
            ),
          );
        }
        if (_controller.monitors.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.desktop_access_disabled, size: 48,
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(80)),
                const SizedBox(height: 12),
                Text('no_monitors_found'.tr,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withAlpha(120))),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _controller.fetchMonitors,
                  icon: const Icon(Icons.refresh),
                  label: Text('refresh'.tr),
                ),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('monitors'.tr,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _controller.fetchMonitors,
                  tooltip: 'refresh'.tr,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _controller.monitors.length,
                itemBuilder: (context, index) {
                  return _buildMonitorCard(context, _controller.monitors[index], index);
                },
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildMonitorCard(BuildContext context, MonitorInfo monitor, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.monitor,
                    color: monitor.isPrimary
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface.withAlpha(180)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(monitor.name,
                      style: Theme.of(context).textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis),
                ),
                if (monitor.isPrimary)
                  Chip(
                    label: Text('primary'.tr,
                        style: const TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(monitor.resolution,
                style: Theme.of(context).textTheme.bodyMedium),
            Text('${'position'.tr}: (${monitor.x}, ${monitor.y})',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Row(
              children: [
                if (!monitor.isPrimary)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _controller.setPrimary(monitor),
                      icon: const Icon(Icons.star_outline, size: 16),
                      label: Text('set_primary'.tr),
                    ),
                  ),
                if (!monitor.isPrimary) const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showResolutionDialog(context, monitor),
                    icon: const Icon(Icons.tune, size: 16),
                    label: Text('set_resolution'.tr),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (index * 80).ms, duration: 400.ms).slideY(begin: 0.1);
  }

  void _showResolutionDialog(BuildContext context, MonitorInfo monitor) {
    final widthCtrl = TextEditingController(text: monitor.width.toString());
    final heightCtrl = TextEditingController(text: monitor.height.toString());
    final refreshCtrl = TextEditingController(text: monitor.refreshRate.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('set_resolution'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: widthCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'width'.tr),
            ),
            TextField(
              controller: heightCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'height'.tr),
            ),
            TextField(
              controller: refreshCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'refresh_rate'.tr),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () {
              final w = int.tryParse(widthCtrl.text) ?? monitor.width;
              final h = int.tryParse(heightCtrl.text) ?? monitor.height;
              final r = int.tryParse(refreshCtrl.text) ?? monitor.refreshRate;
              Navigator.pop(ctx);
              _controller.setResolution(monitor, w, h, r);
            },
            child: Text('apply'.tr),
          ),
        ],
      ),
    );
  }
}
