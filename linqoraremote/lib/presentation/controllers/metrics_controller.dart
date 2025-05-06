import 'package:get/get.dart';

import '../../data/models/metrics.dart';
import '../../data/providers/websocket_provider.dart';

class MetricsController extends GetxController {
  final WebSocketProvider webSocketProvider;

  MetricsController({required this.webSocketProvider});

  static const int maxMetricsCount = 20;

  final temperatures = <int>[].obs;
  final cpuLoads = <int>[].obs;
  final ramUsagesPercent = <int>[].obs;

  final currentCPUMetrics = Rx<CPUMetrics?>(null);
  final currentRAMMetrics = Rx<RAMMetrics?>(null);

  List<int> getTemperatures() => temperatures.toList();
  List<int> getCPULoads() => cpuLoads.toList();
  List<int> getRAMUsagesPercent() => ramUsagesPercent.toList();

  CPUMetrics? getCurrentCPUMetrics() => currentCPUMetrics.value;
  RAMMetrics? getCurrentRAMMetrics() => currentRAMMetrics.value;

  void joinMetricsRoom() {
    webSocketProvider.registerHandler('metrics', _handleMetricsUpdate);
    webSocketProvider.joinRoom('metrics');
  }

  void leaveMetricsRoom() {
    webSocketProvider.leaveRoom('metrics');
    webSocketProvider.removeHandler('metrics');
    _resetMetrics();
  }

  void _handleMetricsUpdate(Map<String, dynamic> data) {
    final metricsData = data['data'] as Map<String, dynamic>;

    currentCPUMetrics.value = CPUMetrics.fromJson(metricsData['cpuMetrics']);
    currentRAMMetrics.value = RAMMetrics.fromJson(metricsData['ramMetrics']);

    _updateMetricsArrays(
      currentCPUMetrics.value!.temperature,
      currentCPUMetrics.value!.loadPercent,
      currentRAMMetrics.value!.loadPercent,
    );
  }

  void _resetMetrics() {
    currentCPUMetrics.value = null;
    currentRAMMetrics.value = null;
    temperatures.clear();
    cpuLoads.clear();
    ramUsagesPercent.clear();
  }

  void _updateMetricsArrays(int temperature, int cpuLoad, int ramUsage) {
    if (temperatures.length >= maxMetricsCount) temperatures.removeAt(0);
    temperatures.add(temperature);

    if (cpuLoads.length >= maxMetricsCount) cpuLoads.removeAt(0);
    cpuLoads.add(cpuLoad);

    if (ramUsagesPercent.length >= maxMetricsCount) ramUsagesPercent.removeAt(0);
    ramUsagesPercent.add(ramUsage);
  }
}