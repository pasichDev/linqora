import 'package:get/get.dart';
import 'package:linqoraremote/data/providers/websocket_provider.dart';

import '../../data/enums/type_request_host.dart';

class KeyboardController extends GetxController {
  final WebSocketProvider webSocketProvider;

  KeyboardController({required this.webSocketProvider});

  // Sticky modifiers — tapping a modifier key toggles it; cleared after a non-modifier key tap.
  final RxSet<String> activeModifiers = <String>{}.obs;

  static const _modifiers = {'ctrl', 'alt', 'shift', 'win'};

  void tapModifier(String mod) {
    if (activeModifiers.contains(mod)) {
      activeModifiers.remove(mod);
    } else {
      activeModifiers.add(mod);
    }
  }

  void tapKey(String key) {
    if (_modifiers.contains(key)) {
      tapModifier(key);
      return;
    }
    _sendKey(key, activeModifiers.toList());
    activeModifiers.clear();
  }

  void typeText(String text) {
    if (text.isEmpty) return;
    if (!webSocketProvider.isReadyForCommand()) return;
    webSocketProvider.sendMessage({
      'type': TypeMessageWs.keyboard_type.value,
      'data': {'text': text},
    });
  }

  void _sendKey(String key, List<String> modifiers) {
    if (!webSocketProvider.isReadyForCommand()) return;
    webSocketProvider.sendMessage({
      'type': TypeMessageWs.keyboard.value,
      'data': {'key': key, 'modifiers': modifiers},
    });
  }
}
