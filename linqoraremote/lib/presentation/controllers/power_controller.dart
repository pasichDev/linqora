import 'package:get/get.dart';
import 'package:linqoraremote/core/utils/error_handler.dart';

import '../../core/utils/app_logger.dart';
import '../../data/enums/type_request_host.dart';
import '../../data/models/ws_message.dart';
import '../../data/providers/websocket_provider.dart';

/// This class is responsible for handling power-related actions
class PowerActions {
  static const int shutDown = 0;
  static const int restart = 1;
  static const int lock = 2;
}

class PowerController extends GetxController {
  final WebSocketProvider webSocketProvider;

  PowerController({required this.webSocketProvider});

  @override
  void onInit() {
    webSocketProvider.registerHandler(
      TypeMessageWs.power.value,
      _handlePowerUpdate,
    );
    super.onInit();
  }

  @override
  void onClose() {
    webSocketProvider.removeHandler(TypeMessageWs.power.value);
    super.onClose();
  }

  /// Handles the power update message from the WebSocket.
  void _handlePowerUpdate(Map<String, dynamic> data) {
    final String indicator = data['data']['status'];

    if (indicator.contains("locked")) {
      showErrorSnackbar('device_locked'.tr, 'ban_commands.tr');
    } else {
      final int action = data['data']['action'];
      _messageSnack(action);
    }
  }

  /// Sends a command to the WebSocket server.
  void fetchCommand(int action) {
    try {
      final message = WsMessage(type: TypeMessageWs.power.value)
        ..setField('data', {'action': action});

      webSocketProvider.sendMessage(message.toJson());
    } catch (e) {
      showErrorSnackbar(
        'error'.tr,
        "${'error_sending_command'.tr}: ${e.toString()}",
      );
      AppLogger.release(
        '${'error_sending_command'.tr}: $e',
        module: "PowerController",
      );
    }
  }

  /// Displays a snackbar message based on the action performed.
  void _messageSnack(int action) {
    String textMessage = 'unknown_action'.tr;

    switch (action) {
      case PowerActions.shutDown:
        textMessage = 'shutdown_device'.tr;
        break;
      case PowerActions.restart:
        textMessage = 'restart_device'.tr;
        break;
      case PowerActions.lock:
        textMessage = 'lock_device'.tr;
        break;
    }

    showErrorSnackbar('running'.tr, textMessage);
  }
}
