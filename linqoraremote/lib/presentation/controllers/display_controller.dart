import 'dart:async';
import 'package:get/get.dart';
import 'package:linqoraremote/data/providers/websocket_provider.dart';

import '../../data/enums/type_request_host.dart';

class DisplayController extends GetxController {
  final WebSocketProvider webSocketProvider;

  DisplayController({required this.webSocketProvider});

  final RxDouble brightness = 50.0.obs;

  Timer? _brightnessDebounce;

  void sleep() => _send('sleep');
  void wake() => _send('wake');

  void onBrightnessChanged(double value) {
    brightness.value = value;
    _brightnessDebounce?.cancel();
    _brightnessDebounce = Timer(const Duration(milliseconds: 300), () {
      _sendBrightness(value.round());
    });
  }

  void _sendBrightness(int level) {
    if (!webSocketProvider.isReadyForCommand()) return;
    webSocketProvider.sendMessage({
      'type': TypeMessageWs.display_cmd.value,
      'data': {'action': 'brightness', 'brightness': level},
    });
  }

  void _send(String action) {
    if (!webSocketProvider.isReadyForCommand()) return;
    webSocketProvider.sendMessage({
      'type': TypeMessageWs.display_cmd.value,
      'data': {'action': action},
    });
  }

  @override
  void onClose() {
    _brightnessDebounce?.cancel();
    super.onClose();
  }
}
