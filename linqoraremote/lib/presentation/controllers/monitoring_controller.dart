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

  final currentCPUMetrics = Rx<CPUMetrics?>(null);
  final currentRAMMetrics = Rx<RAMMetrics?>(null);

  // Internal circular buffers — O(1) writes.
  final _tempBuf = _CircularBuffer<int>(maxMetricsCount);
  final _cpuBuf = _CircularBuffer<int>(maxMetricsCount);
  final _ramBuf = _CircularBuffer<int>(maxMetricsCount);

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
  void onClose() {
    webSocketProvider.leaveRoom(TypeMessageWs.metrics.value);
    webSocketProvider.removeHandler(TypeMessageWs.metrics.value);
    _resetMetrics();
    super.onClose();
  }

  // Buffer for incoming metrics to provide smooth, delayed updates.
  final List<({DateTime timestamp, Map<String, dynamic> data})> _metricsBuffer = [];
  
  void _handleMetricsUpdate(Map<String, dynamic> data) {
    final rawData = data['data'];
    if (rawData == null || rawData is! Map<String, dynamic>) return;

    // Add to buffer with current timestamp
    _metricsBuffer.add((timestamp: DateTime.now(), data: rawData));
    
    // Start processing timer if not already running
    _startBufferTimer();
  }

  bool _isTimerRunning = false;
  void _startBufferTimer() {
    if (_isTimerRunning) return;
    _isTimerRunning = true;
    
    // Check buffer every 500ms
    Stream.periodic(const Duration(milliseconds: 500)).listen((_) {
      _processBuffer();
    });
  }

  void _processBuffer() {
    if (_metricsBuffer.isEmpty) return;

    final now = DateTime.now();
    final delay = const Duration(seconds: 3);

    // Process all metrics that have reached the delay threshold
    while (_metricsBuffer.isNotEmpty && now.difference(_metricsBuffer.first.timestamp) >= delay) {
      final entry = _metricsBuffer.removeAt(0);
      _applyMetrics(entry.data);
    }
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
    _metricsBuffer.clear();
    _tempBuf.clear();
    _cpuBuf.clear();
    _ramBuf.clear();
    temperatures.clear();
    cpuLoads.clear();
    ramUsagesPercent.clear();
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
