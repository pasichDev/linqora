import 'package:get/get.dart';
import 'package:linqoraremote/core/utils/error_handler.dart';

import '../../data/enums/type_messages_ws.dart';
import '../../data/models/ws_message.dart';
import '../../data/providers/websocket_provider.dart';

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

  void _handlePowerUpdate(Map<String, dynamic> data) {
    final String indicator = data['data']['status'];

    if (indicator.contains("locked")) {
      showErrorSnackbar(
        "Пристрій заблоковано",
        "Команди керування живленням не доступні",
      );
    } else {
      final int action = data['data']['action'];
      _messageSnack(action);
    }
  }

  void fetchCommand(int action) {
    try {
      final message = WsMessage(type: TypeMessageWs.power.value)
        ..setField('data', {'action': action});

      webSocketProvider.sendMessage(message.toJson());
    } catch (e) {
      showErrorSnackbar(
        "Помилка",
        "Не вдалося надіслати команду: ${e.toString()}",
      );
    }
  }

  void _messageSnack(int action) {
    String textMessage = "Невідома дія";

    switch (action) {
      case PowerActions.shutDown:
        textMessage = "Вимкнення пристрою...";
        break;
      case PowerActions.restart:
        textMessage = "Перезавантаження пристрою...";
        break;
      case PowerActions.lock:
        textMessage = "Блокування пристрою...";
        break;
    }

    showErrorSnackbar('Виконується', textMessage);
  }
}
