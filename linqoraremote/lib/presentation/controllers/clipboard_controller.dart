import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/data/providers/websocket_provider.dart';
import '../../data/enums/type_request_host.dart';

class ClipboardController extends GetxController {
  final WebSocketProvider webSocketProvider;
  ClipboardController({required this.webSocketProvider});

  final RxString hostClipboard = ''.obs;
  final RxBool sending = false.obs;

  /// History: newest first, capped at 50.
  final RxList<ClipEntry> history = <ClipEntry>[].obs;

  static const _maxHistory = 50;

  @override
  void onInit() {
    webSocketProvider.registerHandler(
      TypeMessageWs.clipboard_update.value,
      _onHostClipboard,
    );
    webSocketProvider.joinRoom('clipboard');
    super.onInit();
  }

  @override
  void onClose() {
    webSocketProvider.leaveRoom('clipboard');
    webSocketProvider.removeHandler(TypeMessageWs.clipboard_update.value);
    history.clear();
    super.onClose();
  }

  void _onHostClipboard(Map<String, dynamic> message) {
    final data = message['data'];
    final text = data is String
        ? data
        : (data is Map ? data['text'] as String? : null) ?? '';
    if (text.isEmpty) return;
    if (hostClipboard.value == text) return;
    hostClipboard.value = text;
    history.insert(0, ClipEntry(text: text, time: DateTime.now()));
    if (history.length > _maxHistory) history.removeLast();
  }

  Future<void> copyHostClipboard() async {
    if (hostClipboard.value.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: hostClipboard.value));
  }

  Future<void> copyHistoryEntry(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> sendToHost() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.isEmpty || !webSocketProvider.isReadyForCommand()) return;
    sending.value = true;
    webSocketProvider.sendMessage({
      'type': TypeMessageWs.clipboard_set.value,
      'data': {'text': text},
    });
    sending.value = false;
  }
}

class ClipEntry {
  final String text;
  final DateTime time;
  ClipEntry({required this.text, required this.time});
}
