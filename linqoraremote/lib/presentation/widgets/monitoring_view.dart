import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/core/themes/lx_theme.dart';
import 'package:linqoraremote/data/models/metrics.dart';
import 'package:linqoraremote/data/providers/websocket_provider.dart';
import 'package:linqoraremote/presentation/controllers/device_home_controller.dart';
import 'package:linqoraremote/presentation/controllers/monitoring_controller.dart';
import 'package:linqoraremote/presentation/widgets/lx_glass.dart';
import 'package:linqoraremote/presentation/widgets/lx_header.dart';
import 'package:linqoraremote/presentation/widgets/lx_ring.dart';
import 'package:linqoraremote/presentation/widgets/lx_sparkline.dart';

class MonitoringView extends StatefulWidget {
  const MonitoringView({super.key});

  @override
  State<MonitoringView> createState() => _MonitoringViewState();
}

class _MonitoringViewState extends State<MonitoringView>
    with SingleTickerProviderStateMixin {
  late final MonitoringController _c;
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _c = Get.put(
      MonitoringController(webSocketProvider: Get.find<WebSocketProvider>()),
    );

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    if (Get.isRegistered<MonitoringController>()) {
      Get.delete<MonitoringController>();
    }
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Obx(() {
        final cpu = _c.currentCPUMetrics.value;
        final ram = _c.currentRAMMetrics.value;

        if (cpu == null && ram == null) {
          return _loading();
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          child: Column(
            children: [
              _header(),
              _heroCpuCard(cpu),
              const SizedBox(height: 10),
              _ramGpuRow(ram, _c.currentGPULoadPercent.value, _c.currentGPUTemperature.value),
              const SizedBox(height: 10),
              _perCoreCard(cpu),
              const SizedBox(height: 10),
              _statTiles(cpu),
              const SizedBox(height: 10),
              _diskNetRow(),
              const SizedBox(height: 20),
            ],
          ),
        );
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _header() {
    final homeCtrl = Get.find<DeviceHomeController>();
    return LxHeader(
      title: 'Monitor',
      eyebrow: homeCtrl.hostInfo.value?.hostname ?? 'Device',
      showBack: false,
      action: GestureDetector(
        onTap: () => homeCtrl.refreshHostInfo(),
        child: LxGlass(
          borderRadius: BorderRadius.circular(12),
          child: const SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: Icon(Icons.refresh_rounded, size: 14, color: lxTextDim),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hero CPU card
  // ---------------------------------------------------------------------------

  Widget _heroCpuCard(CPUMetrics? cpu) {
    final host = Get.find<DeviceHomeController>().hostInfo.value;
    return LxGlass(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          LxRing(
            value: cpu?.loadPercent.toDouble() ?? 0,
            size: 86,
            strokeWidth: 2.8,
            label: 'CPU',
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        host?.cpu.model ?? 'CPU',
                        style: const TextStyle(
                          fontSize: 12,
                          color: lxTextDim,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${(host?.cpu.frequency ?? 0).toStringAsFixed(0)} MHz',
                      style: const TextStyle(
                        fontSize: 11,
                        color: lxTextFaint,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LxSparkline(
                  data: _c.cpuLoads,
                  width: 170,
                  height: 42,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _mini('Processes', cpu?.processes.toString() ?? '--'),
                    const SizedBox(width: 12),
                    _mini('Threads', cpu?.threads.toString() ?? '--'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RAM + GPU side-by-side
  // ---------------------------------------------------------------------------

  Widget _ramGpuRow(RAMMetrics? ram, int? gpuLoad, int? gpuTemp) {
    final host = Get.find<DeviceHomeController>().hostInfo.value;
    final totalRam = host?.ram.total ?? 0.0;
    final usedRam = ram?.usage ?? 0.0;
    final gpuModel = host?.gpu.model ?? '';
    final gpuMemory = host?.gpu.memory ?? 0;

    return Row(
      children: [
        // RAM card
        Expanded(
          child: LxGlass(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'RAM',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        color: lxTextFaint,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${usedRam.toStringAsFixed(1)}/${totalRam.toStringAsFixed(0)} GB',
                      style: const TextStyle(fontSize: 10, color: lxTextFaint),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${_c.currentRAMMetrics.value?.loadPercent ?? 0}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.8,
                          color: lxText,
                        ),
                      ),
                      const TextSpan(
                        text: '%',
                        style: TextStyle(fontSize: 14, color: lxTextDim),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                LxSparkline(
                  data: _c.ramUsagesPercent,
                  width: 130,
                  height: 32,
                  color: const Color(0xFF7C9CFF),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        // GPU card
        Expanded(
          child: LxGlass(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'GPU',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        color: lxTextFaint,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (gpuMemory > 0)
                      Text(
                        '${(gpuMemory / 1024).toStringAsFixed(0)} GB',
                        style: const TextStyle(fontSize: 10, color: lxTextFaint),
                      )
                    else if (gpuModel.isNotEmpty && gpuModel != 'Unknown')
                      Flexible(
                        child: Text(
                          gpuModel,
                          style: const TextStyle(fontSize: 9, color: lxTextFaint),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: gpuLoad != null ? '$gpuLoad' : '—',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.8,
                          color: lxText,
                        ),
                      ),
                      if (gpuLoad != null)
                        const TextSpan(
                          text: '%',
                          style: TextStyle(fontSize: 14, color: lxTextDim),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                gpuLoad != null
                    ? LxSparkline(
                        data: _c.gpuLoads,
                        width: 130,
                        height: 32,
                        color: const Color(0xFF9C7CFF),
                      )
                    : Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: lxGlass2,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                if (gpuTemp != null && gpuTemp > 0) ...[
                  const SizedBox(height: 6),
                  _mini('GPU TEMP', '${gpuTemp}°C'),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Per-core load grid
  // ---------------------------------------------------------------------------

  Widget _perCoreCard(CPUMetrics? cpu) {
    final host = Get.find<DeviceHomeController>().hostInfo.value;
    final coreCount =
        (host?.cpu.logicalCores ?? 0) > 0 ? host!.cpu.logicalCores : 8;
    final loadVal = cpu?.loadPercent ?? 0;

    return LxGlass(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PER-CORE LOAD',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  color: lxTextFaint,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$coreCount cores',
                style: const TextStyle(fontSize: 10, color: lxTextFaint),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(coreCount, (i) {
              final offset = (i - (coreCount / 2)).round() * 6;
              final v = (loadVal + offset).clamp(0, 100).toDouble();
              final isHot = v > 75;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 32,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: lxGlass2,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            FractionallySizedBox(
                              heightFactor: v / 100,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  gradient: isHot
                                      ? const LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [lxAmber, lxAccent],
                                        )
                                      : null,
                                  color: isHot
                                      ? null
                                      : lxAccent.withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'C$i',
                        style: const TextStyle(
                          fontSize: 9,
                          color: lxTextFaint,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Stat tiles: temp + processes
  // ---------------------------------------------------------------------------

  Widget _statTiles(CPUMetrics? cpu) {
    return Row(
      children: [
        // CPU temperature tile
        Expanded(
          child: LxGlass(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: lxGlass2,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.thermostat_rounded,
                      size: 14,
                      color: lxAmber,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CPU TEMP',
                      style: TextStyle(
                        fontSize: 10,
                        color: lxTextFaint,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      (cpu != null && cpu.temperature > 0) ? '${cpu.temperature}°C' : '--',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: lxText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Processes tile
        Expanded(
          child: LxGlass(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: lxGlass2,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.memory_rounded,
                      size: 14,
                      color: lxAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PROCESSES',
                        style: TextStyle(
                          fontSize: 10,
                          color: lxTextFaint,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        cpu?.processes.toString() ?? '--',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: lxText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Disk + Network row
  // ---------------------------------------------------------------------------

  Widget _diskNetRow() {
    return Row(
      children: [
        Expanded(
          child: LxGlass(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: lxGlass2,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Center(
                        child: Icon(Icons.storage_rounded, size: 12, color: lxAccent),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'DISK',
                      style: TextStyle(fontSize: 10, color: lxTextFaint, letterSpacing: 1),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Obx(() => _ioRow('R', _c.diskReadBps.value)),
                const SizedBox(height: 2),
                Obx(() => _ioRow('W', _c.diskWriteBps.value)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: LxGlass(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: lxGlass2,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Center(
                        child: Icon(Icons.wifi_rounded, size: 12, color: Color(0xFF7C9CFF)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'NET',
                      style: TextStyle(fontSize: 10, color: lxTextFaint, letterSpacing: 1),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Obx(() => _ioRow('↑', _c.netSentBps.value)),
                const SizedBox(height: 2),
                Obx(() => _ioRow('↓', _c.netRecvBps.value)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _ioRow(String label, int bps) {
    return Row(
      children: [
        SizedBox(
          width: 14,
          child: Text(
            label,
            style: const TextStyle(fontSize: 10, color: lxTextFaint),
          ),
        ),
        Text(
          _formatBps(bps),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: lxText,
          ),
        ),
      ],
    );
  }

  String _formatBps(int bps) {
    if (bps < 1024) return '$bps B/s';
    if (bps < 1024 * 1024) return '${(bps / 1024).toStringAsFixed(0)} KB/s';
    return '${(bps / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Widget _mini(String label, String val) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: const TextStyle(fontSize: 10.5, color: lxTextDim),
          ),
          TextSpan(
            text: val,
            style: const TextStyle(
              fontSize: 10.5,
              color: lxText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _loading() {
    return const Center(
      child: CircularProgressIndicator(color: lxAccent, strokeWidth: 2),
    );
  }
}
