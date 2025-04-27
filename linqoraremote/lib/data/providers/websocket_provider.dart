import 'package:get/get.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketProvider {
  WebSocketChannel? _channel;
  final RxList<String> messages = <String>[].obs;

  Function()? onConnected;
  Function()? onDisconnected;
  Function(Object error)? onError;

  WebSocketChannel connect(String ip, int port) {
    final wsUrl = 'ws://$ip:$port/ws';
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

    onConnected?.call();

    _channel!.stream.listen(
      (message) {
        messages.add(message);
      },
      onDone: () {
        onDisconnected?.call();
      },
      onError: (error) {
        onError?.call(error);
      },
    );

    return _channel!;
  }

  void send(String message) {
    _channel?.sink.add(message);
  }

  void close() {
    _channel?.sink.close();
    _channel = null;
  }
}
