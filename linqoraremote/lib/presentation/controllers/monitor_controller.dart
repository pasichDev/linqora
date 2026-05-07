import 'package:get/get.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/error_handler.dart';
import '../../data/enums/type_request_host.dart';
import '../../data/models/monitor_info.dart';
import '../../data/models/ws_message.dart';
import '../../data/providers/websocket_provider.dart';

class MonitorController extends GetxController {
  final WebSocketProvider webSocketProvider;

  MonitorController({required this.webSocketProvider});

  final monitors = <MonitorInfo>[].obs;
  final isLoading = false.obs;
  final errorMessage = ''.obs;

  @override
  void onInit() {
    webSocketProvider.registerHandler(
      TypeMessageWs.monitor_list.value,
      _handleMonitorList,
    );
    webSocketProvider.registerHandler(
      TypeMessageWs.monitor_set_resolution.value,
      _handleCommandResult,
    );
    webSocketProvider.registerHandler(
      TypeMessageWs.monitor_set_primary.value,
      _handleCommandResult,
    );
    fetchMonitors();
    super.onInit();
  }

  @override
  void onClose() {
    webSocketProvider.removeHandler(TypeMessageWs.monitor_list.value);
    webSocketProvider.removeHandler(TypeMessageWs.monitor_set_resolution.value);
    webSocketProvider.removeHandler(TypeMessageWs.monitor_set_primary.value);
    super.onClose();
  }

  void fetchMonitors() {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final msg = WsMessage(type: TypeMessageWs.monitor_list.value);
      webSocketProvider.sendMessage(msg.toJson());
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = e.toString();
      AppLogger.release('MonitorController fetchMonitors error: $e', module: 'MonitorController');
    }
  }

  void _handleMonitorList(Map<String, dynamic> data) {
    isLoading.value = false;
    if (data['status'] == 'error') {
      errorMessage.value = data['message'] ?? 'error'.tr;
      return;
    }
    final raw = data['data'] as List<dynamic>? ?? [];
    monitors.value = raw.map((e) => MonitorInfo.fromJson(e as Map<String, dynamic>)).toList();
  }

  void setResolution(MonitorInfo monitor, int width, int height, int refreshRate) {
    try {
      final msg = WsMessage(type: TypeMessageWs.monitor_set_resolution.value)
        ..setField('data', {
          'monitor_id': monitor.id,
          'width': width,
          'height': height,
          'refresh_rate': refreshRate,
        });
      webSocketProvider.sendMessage(msg.toJson());
    } catch (e) {
      showErrorSnackbar('error'.tr, e.toString());
    }
  }

  void setPrimary(MonitorInfo monitor) {
    try {
      final msg = WsMessage(type: TypeMessageWs.monitor_set_primary.value)
        ..setField('data', {'monitor_id': monitor.id});
      webSocketProvider.sendMessage(msg.toJson());
    } catch (e) {
      showErrorSnackbar('error'.tr, e.toString());
    }
  }

  void _handleCommandResult(Map<String, dynamic> data) {
    if (data['status'] == 'error') {
      showErrorSnackbar('error'.tr, data['message'] ?? 'error'.tr);
    } else {
      fetchMonitors();
    }
  }
}
