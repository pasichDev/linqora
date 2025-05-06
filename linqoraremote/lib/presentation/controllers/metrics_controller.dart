import 'package:get/get.dart';

import '../../data/models/metrics.dart';
import '../../data/providers/websocket_provider.dart';

class MetricsController extends GetxController {
  final WebSocketProvider webSocketProvider;

  MetricsController({required this.webSocketProvider});

  static const int maxMetricsCount = 20;

  final temperatures = <double>[].obs;
  final cpuLoads = <double>[].obs;
  final ramUsages = <double>[].obs;

  final currentCPUMetrics = Rx<CPUMetrics?>(null);
  final currentRAMMetrics = Rx<RAMMetrics?>(null);

  List<double> getTemperatures() => temperatures.toList();
  List<double> getCPULoads() => cpuLoads.toList();
  List<double> getRAMUsages() => ramUsages.toList();

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
      currentRAMMetrics.value!.usage,
    );
  }

  void _resetMetrics() {
    currentCPUMetrics.value = null;
    currentRAMMetrics.value = null;
    temperatures.clear();
    cpuLoads.clear();
    ramUsages.clear();
  }

  void _updateMetricsArrays(double temperature, double cpuLoad, double ramUsage) {
    if (temperatures.length >= maxMetricsCount) temperatures.removeAt(0);
    temperatures.add(temperature);

    if (cpuLoads.length >= maxMetricsCount) cpuLoads.removeAt(0);
    cpuLoads.add(cpuLoad);

    if (ramUsages.length >= maxMetricsCount) ramUsages.removeAt(0);
    ramUsages.add(ramUsage);
  }
}