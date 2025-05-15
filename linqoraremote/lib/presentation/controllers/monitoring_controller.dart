import 'package:get/get.dart';

import '../../data/enums/type_messages_ws.dart';
import '../../data/models/metrics.dart';
import '../../data/providers/websocket_provider.dart';

class MonitoringController extends GetxController {
  final WebSocketProvider webSocketProvider;

  MonitoringController({required this.webSocketProvider});

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

  bool get hasEnoughMetricsData =>
      temperatures.length > 5 &&
      cpuLoads.length > 5 &&
      ramUsagesPercent.length > 5;

  @override
  void onInit() {
    webSocketProvider.registerHandler(
      TypeMessageWs.metrics.value,
      _handleMetricsUpdate,
    );
    webSocketProvider.joinRoom(TypeMessageWs.metrics.value);
    super.onInit();
  }

  @override
  void dispose() {
    webSocketProvider.leaveRoom(TypeMessageWs.metrics.value);
    webSocketProvider.removeHandler(TypeMessageWs.metrics.value);
    _resetMetrics();
    super.dispose();
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

    if (ramUsagesPercent.length >= maxMetricsCount) {
      ramUsagesPercent.removeAt(0);
    }
    ramUsagesPercent.add(ramUsage);
  }
}
