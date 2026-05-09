import 'package:get/get.dart';

import '../../core/utils/app_logger.dart';
import '../../core/utils/error_handler.dart';
import '../../data/enums/type_request_host.dart';
import '../../data/providers/websocket_provider.dart';

class ProcessInfo {
  final int pid;
  final String name;
  final double cpu;
  final int rss;
  final String status;

  const ProcessInfo({
    required this.pid,
    required this.name,
    required this.cpu,
    required this.rss,
    required this.status,
  });

  factory ProcessInfo.fromJson(Map<String, dynamic> j) => ProcessInfo(
        pid: (j['pid'] as num).toInt(),
        name: j['name'] as String? ?? '',
        cpu: (j['cpu'] as num?)?.toDouble() ?? 0.0,
        rss: (j['rss'] as num?)?.toInt() ?? 0,
        status: j['status'] as String? ?? '',
      );

  String get rssFormatted {
    if (rss < 1024 * 1024) return '${(rss / 1024).toStringAsFixed(0)} KB';
    return '${(rss / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

enum ProcessSort { cpu, ram, name }

class ProcessController extends GetxController {
  final WebSocketProvider webSocketProvider;

  ProcessController({required this.webSocketProvider});

  final processes = <ProcessInfo>[].obs;
  final isLoading = false.obs;
  final sort = ProcessSort.cpu.obs;

  List<ProcessInfo> get sorted {
    final list = List<ProcessInfo>.from(processes);
    switch (sort.value) {
      case ProcessSort.cpu:
        list.sort((a, b) => b.cpu.compareTo(a.cpu));
      case ProcessSort.ram:
        list.sort((a, b) => b.rss.compareTo(a.rss));
      case ProcessSort.name:
        list.sort((a, b) => a.name.compareTo(b.name));
    }
    return list;
  }

  @override
  void onInit() {
    super.onInit();
    webSocketProvider.registerHandler(
      TypeMessageWs.process_list.value,
      _handleProcessList,
    );
    webSocketProvider.registerHandler(
      TypeMessageWs.process_kill.value,
      _handleProcessKill,
    );
    fetchProcesses();
  }

  @override
  void onClose() {
    webSocketProvider.removeHandler(TypeMessageWs.process_list.value);
    webSocketProvider.removeHandler(TypeMessageWs.process_kill.value);
    super.onClose();
  }

  void fetchProcesses() {
    if (!webSocketProvider.isConnected) return;
    isLoading.value = true;
    webSocketProvider.sendMessage({'type': TypeMessageWs.process_list.value});
  }

  void killProcess(int pid) {
    if (!webSocketProvider.isConnected) return;
    webSocketProvider.sendMessage({
      'type': TypeMessageWs.process_kill.value,
      'data': {'pid': pid},
    });
  }

  void _handleProcessList(Map<String, dynamic> data) {
    try {
      isLoading.value = false;
      final payload = data['data'];
      if (payload == null) return;
      final list = (payload['processes'] as List?)
              ?.map((e) => ProcessInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      processes.value = list;
    } catch (e) {
      isLoading.value = false;
      AppLogger.release('Error parsing process list: $e', module: 'ProcessController');
    }
  }

  void _handleProcessKill(Map<String, dynamic> data) {
    final status = data['status'];
    if (status == 'error') {
      final msg = (data['error'] as Map<String, dynamic>?)?['message'] ?? 'Kill failed';
      showErrorSnackbar('Process', msg.toString());
      return;
    }
    // Refresh after successful kill
    fetchProcesses();
  }
}
