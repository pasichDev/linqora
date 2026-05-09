import 'package:get/get.dart';

import '../../core/utils/app_logger.dart';
import '../../data/enums/type_request_host.dart';
import '../../data/models/metrics.dart';
import '../../data/providers/websocket_provider.dart';

// ---------------------------------------------------------------------------
// Circular buffer — O(1) add, no array shifting, single allocation.
// ---------------------------------------------------------------------------
class _CircularBuffer<T> {
  final int capacity;
  final List<T?> _buf;
  int _head = 0;
  int _count = 0;

  _CircularBuffer(this.capacity) : _buf = List.filled(capacity, null);

  void add(T value) {
    _buf[_head] = value;
    _head = (_head + 1) % capacity;
    if (_count < capacity) _count++;
  }

  /// Returns elements in insertion order (oldest → newest).
  List<T> toList() {
    if (_count == 0) return [];
    if (_count < capacity) {
      return _buf.take(_count).cast<T>().toList();
    }
    // Buffer is full: oldest element is at _head.
    return [..._buf.skip(_head).cast<T>(), ..._buf.take(_head).cast<T>()];
  }

  void clear() {
    _head = 0;
    _count = 0;
    _buf.fillRange(0, capacity, null);
  }
}

// ---------------------------------------------------------------------------

class MonitoringController extends GetxController {
  final WebSocketProvider webSocketProvider;

  MonitoringController({required this.webSocketProvider});

  static const int maxMetricsCount = 40;

  // RxList used for UI reactivity; updated in a single batch per tick.
  final temperatures = <int>[].obs;
  final cpuLoads = <int>[].obs;
  final ramUsagesPercent = <int>[].obs;
  final gpuLoads = <int>[].obs;

  final currentCPUMetrics = Rx<CPUMetrics?>(null);
  final currentRAMMetrics = Rx<RAMMetrics?>(null);
  final currentGPULoadPercent = Rx<int?>(null);
  final currentGPUTemperature = Rx<int?>(null);

  final diskReadBps = 0.obs;
  final diskWriteBps = 0.obs;
  final netSentBps = 0.obs;
  final netRecvBps = 0.obs;

  // Internal circular buffers — O(1) writes.
  final _tempBuf = _CircularBuffer<int>(maxMetricsCount);
  final _cpuBuf = _CircularBuffer<int>(maxMetricsCount);
  final _ramBuf = _CircularBuffer<int>(maxMetricsCount);
  final _gpuBuf = _CircularBuffer<int>(maxMetricsCount);

  List<int> getTemperatures() => temperatures.toList();
  List<int> getCPULoads() => cpuLoads.toList();
  List<int> getRAMUsagesPercent() => ramUsagesPercent.toList();

  CPUMetrics? getCurrentCPUMetrics() => currentCPUMetrics.value;
  RAMMetrics? getCurrentRAMMetrics() => currentRAMMetrics.value;

  bool get hasEnoughMetricsData =>
      temperatures.isNotEmpty &&
      cpuLoads.isNotEmpty &&
      ramUsagesPercent.isNotEmpty;

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
  void onClose() {
    webSocketProvider.leaveRoom(TypeMessageWs.metrics.value);
    webSocketProvider.removeHandler(TypeMessageWs.metrics.value);
    _resetMetrics();
    super.onClose();
  }

  void _handleMetricsUpdate(Map<String, dynamic> data) {
    final rawData = data['data'];
    if (rawData == null || rawData is! Map<String, dynamic>) return;
    _applyMetrics(rawData);
  }

  void _applyMetrics(Map<String, dynamic> rawData) {
    try {
      final cpuJson = rawData['cpuMetrics'];
      final ramJson = rawData['ramMetrics'];
      if (cpuJson == null || ramJson == null) return;

      currentCPUMetrics.value = CPUMetrics.fromJson(
        cpuJson as Map<String, dynamic>,
      );
      currentRAMMetrics.value = RAMMetrics.fromJson(
        ramJson as Map<String, dynamic>,
      );

      final gpuLoad = rawData['gpuLoadPercent'];
      if (gpuLoad != null) {
        currentGPULoadPercent.value = (gpuLoad as num).toInt();
        _gpuBuf.add(currentGPULoadPercent.value!);
        gpuLoads.value = _gpuBuf.toList();
      }

      final gpuTemp = rawData['gpuTemperature'];
      if (gpuTemp != null) {
        final t = (gpuTemp as num).toInt();
        if (t > 0) currentGPUTemperature.value = t;
      }

      final dr = rawData['diskReadBps'];
      if (dr != null) diskReadBps.value = (dr as num).toInt();
      final dw = rawData['diskWriteBps'];
      if (dw != null) diskWriteBps.value = (dw as num).toInt();
      final ns = rawData['netSentBps'];
      if (ns != null) netSentBps.value = (ns as num).toInt();
      final nr = rawData['netRecvBps'];
      if (nr != null) netRecvBps.value = (nr as num).toInt();

      _updateMetricsArrays(
        currentCPUMetrics.value!.temperature,
        currentCPUMetrics.value!.loadPercent,
        currentRAMMetrics.value!.loadPercent,
      );
    } catch (e) {
      AppLogger.release(
        'Error applying metrics: $e',
        module: 'MonitoringController',
      );
    }
  }

  void _resetMetrics() {
    currentCPUMetrics.value = null;
    currentRAMMetrics.value = null;
    currentGPULoadPercent.value = null;
    currentGPUTemperature.value = null;
    diskReadBps.value = 0;
    diskWriteBps.value = 0;
    netSentBps.value = 0;
    netRecvBps.value = 0;
    _tempBuf.clear();
    _cpuBuf.clear();
    _ramBuf.clear();
    _gpuBuf.clear();
    temperatures.clear();
    cpuLoads.clear();
    ramUsagesPercent.clear();
    gpuLoads.clear();
  }

  /// Appends new samples to the circular buffers, then batch-updates the
  /// three RxLists in one assignment each — one UI rebuild per tick instead
  /// of three separate removeAt(0)/add() cycles.
  void _updateMetricsArrays(int temperature, int cpuLoad, int ramUsage) {
    _tempBuf.add(temperature);
    _cpuBuf.add(cpuLoad);
    _ramBuf.add(ramUsage);

    temperatures.value = _tempBuf.toList();
    cpuLoads.value = _cpuBuf.toList();
    ramUsagesPercent.value = _ramBuf.toList();
  }
}
