import 'package:get/get.dart';

import '../../core/utils/app_logger.dart';
import '../../core/utils/error_handler.dart';
import '../../data/enums/type_request_host.dart';
import '../../data/providers/websocket_provider.dart';

class StartupEntry {
  final String name;
  final String command;
  final bool enabled;

  const StartupEntry({
    required this.name,
    required this.command,
    required this.enabled,
  });

  factory StartupEntry.fromJson(Map<String, dynamic> j) => StartupEntry(
        name: j['name'] as String? ?? '',
        command: j['command'] as String? ?? '',
        enabled: j['enabled'] as bool? ?? false,
      );

  StartupEntry copyWith({bool? enabled}) => StartupEntry(
        name: name,
        command: command,
        enabled: enabled ?? this.enabled,
      );
}

class StartupController extends GetxController {
  final WebSocketProvider webSocketProvider;

  StartupController({required this.webSocketProvider});

  final entries = <StartupEntry>[].obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    webSocketProvider.registerHandler(
      TypeMessageWs.startup_list.value,
      _handleStartupList,
    );
    webSocketProvider.registerHandler(
      TypeMessageWs.startup_set.value,
      _handleStartupSet,
    );
    fetchEntries();
  }

  @override
  void onClose() {
    webSocketProvider.removeHandler(TypeMessageWs.startup_list.value);
    webSocketProvider.removeHandler(TypeMessageWs.startup_set.value);
    super.onClose();
  }

  void fetchEntries() {
    if (!webSocketProvider.isConnected) return;
    isLoading.value = true;
    webSocketProvider.sendMessage({'type': TypeMessageWs.startup_list.value});
  }

  void toggleEntry(String name, bool enabled) {
    if (!webSocketProvider.isConnected) return;
    // Optimistic update
    final idx = entries.indexWhere((e) => e.name == name);
    if (idx >= 0) entries[idx] = entries[idx].copyWith(enabled: enabled);
    webSocketProvider.sendMessage({
      'type': TypeMessageWs.startup_set.value,
      'data': {'name': name, 'enabled': enabled},
    });
  }

  void _handleStartupList(Map<String, dynamic> data) {
    try {
      isLoading.value = false;
      final payload = data['data'];
      if (payload == null) return;
      final list = (payload['entries'] as List?)
              ?.map((e) => StartupEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      entries.value = list;
    } catch (e) {
      isLoading.value = false;
      AppLogger.release('Error parsing startup list: $e', module: 'StartupController');
    }
  }

  void _handleStartupSet(Map<String, dynamic> data) {
    if (data['status'] == 'error') {
      final msg = (data['error'] as Map<String, dynamic>?)?['message'] ?? 'Toggle failed';
      showErrorSnackbar('Startup', msg.toString());
      fetchEntries(); // revert
    }
  }
}
