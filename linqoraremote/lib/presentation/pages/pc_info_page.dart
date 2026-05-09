import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/themes/lx_theme.dart';
import '../controllers/device_home_controller.dart';
import '../widgets/lx_background.dart';
import '../widgets/lx_glass.dart';
import '../widgets/lx_header.dart';

class PcInfoPage extends StatelessWidget {
  const PcInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<DeviceHomeController>();
    return LxBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Obx(() {
            final info = ctrl.hostInfo.value;
            if (info == null) {
              return const Center(
                child: CircularProgressIndicator(
                  color: lxAccent,
                  strokeWidth: 2,
                ),
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const LxHeader(title: 'PC Info', showBack: true),
                  _section('System', [
                    _row('Hostname', info.baseInfo.hostname),
                    _row('OS', info.baseInfo.os),
                    _row('Platform Version', info.platformVersion.isNotEmpty ? info.platformVersion : '—'),
                    _row('Kernel', info.kernelVersion.isNotEmpty ? info.kernelVersion : '—'),
                    _row('Architecture', info.architecture.isNotEmpty ? info.architecture : '—'),
                    _row('IP Address', info.baseInfo.ip.isNotEmpty ? info.baseInfo.ip : '—'),
                    _row('Uptime', _fmtUptime(info.uptime)),
                  ]),
                  const SizedBox(height: 16),
                  _section('Processor', [
                    _row('CPU Model', info.cpu.model),
                    _row('Physical Cores', info.cpu.physicalCores > 0 ? '${info.cpu.physicalCores}' : '—'),
                    _row('Logical Cores', info.cpu.logicalCores > 0 ? '${info.cpu.logicalCores}' : '—'),
                    _row(
                      'Base Frequency',
                      info.cpu.frequency > 0
                          ? '${info.cpu.frequency.toStringAsFixed(2)} GHz'
                          : '—',
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _section('Memory', [
                    _row('Total RAM', info.ram.total > 0 ? _fmtGb(info.ram.total) : '—'),
                    _row('Used RAM', info.ram.used > 0 ? _fmtGb(info.ram.used) : '—'),
                    _row('Free RAM', info.ram.free > 0 ? _fmtGb(info.ram.free) : '—'),
                    _row('Type', info.ram.type.isNotEmpty && info.ram.type != 'Unknown' ? info.ram.type : '—'),
                    _row(
                      'Frequency',
                      info.ram.frequency > 0 ? '${info.ram.frequency} MHz' : '—',
                    ),
                    _row('Slots', info.ram.slots > 0 ? '${info.ram.slots}' : '—'),
                  ]),
                  const SizedBox(height: 16),
                  _section('Graphics', [
                    _row('GPU Model', info.gpu.model.isNotEmpty && info.gpu.model != 'Unknown' ? info.gpu.model : '—'),
                    _row(
                      'VRAM',
                      info.gpu.memory > 0 ? '${info.gpu.memory} MB' : '—',
                    ),
                  ]),
                  if (info.disks.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _section(
                      'Storage',
                      info.disks.map((disk) {
                        final label = disk.name.isNotEmpty ? disk.name : disk.mountPath;
                        return _diskRow(label, disk.used, disk.total, disk.fileSystem);
                      }).toList(),
                    ),
                  ],
                  if (info.battery.isPresent) ...[
                    const SizedBox(height: 16),
                    _section('Battery', [
                      _row('Level', '${info.battery.level}%'),
                      _row('Status', info.battery.status),
                      _row('Charging', info.battery.isCharging ? 'Yes' : 'No'),
                    ]),
                  ],
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 1.4,
            color: lxTextFaint,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        LxGlass(
          child: Column(children: rows),
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: lxHairline, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: lxTextDim),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: lxText,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _diskRow(String label, double used, double total, String fs) {
    final percent = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
    final usedStr = _fmtGb(used);
    final totalStr = _fmtGb(total);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: lxHairline, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 13, color: lxText, fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                '$usedStr / $totalStr',
                style: const TextStyle(fontSize: 12, color: lxTextDim),
              ),
            ],
          ),
          if (fs.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(fs, style: const TextStyle(fontSize: 11, color: lxTextFaint)),
          ],
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 3,
              backgroundColor: lxHairlineHi,
              valueColor: AlwaysStoppedAnimation<Color>(
                percent > 0.85 ? lxRed : lxAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtGb(double mb) {
    if (mb >= 1024) return '${(mb / 1024).toStringAsFixed(1)} GB';
    return '${mb.toStringAsFixed(0)} MB';
  }

  String _fmtUptime(int seconds) {
    if (seconds <= 0) return 'Unknown';
    final d = seconds ~/ 86400;
    final h = (seconds % 86400) ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (d > 0) return '${d}d ${h}h ${m}m';
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}
