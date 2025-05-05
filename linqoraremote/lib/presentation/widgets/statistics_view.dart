import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/device_home_controller.dart';

class StatisticsView extends StatefulWidget {
  const StatisticsView({super.key});

  @override
  State<StatisticsView> createState() => _StatisticsViewState();
}

class _StatisticsViewState extends State<StatisticsView> {
  late DeviceHomeController controller;
  @override
  void initState() {
    super.initState();
    controller = Get.find<DeviceHomeController>();
    controller.joinMetricsRoom();
  }

  @override
  void dispose() {
    super.dispose();
    controller.leaveMetricsRoom();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Статистика',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        Expanded(
          child: Obx(() {
            final cpuMetrics = controller.getCurrentCPUMetrics();
            final ramMetrics = controller.getCurrentRAMMetrics();

            if (cpuMetrics == null || ramMetrics == null) {
              return Center(child: CircularProgressIndicator());
            }

            return Column(
              children: [
                Text('CPU Temperature: ${cpuMetrics.temperature}°C'),
                Text('CPU Load: ${cpuMetrics.loadPercent}%'),
                Text('RAM Usage: ${ramMetrics.usage}GB'),
                Text('RAM Load: ${ramMetrics.loadPercent}%'),
              ],
            );
          }),
        ),
      ],
    );
  }
}
