import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../enums/type_messages_ws.dart';
import '../models/ws_message.dart';

class WebSocketProvider {
  WebSocketChannel? _channel;
  final RxList<String> messages = <String>[].obs;

  Function()? onConnected;
  Function()? onDisconnected;
  Function(Object error)? onError;

  final Map<String, Function(Map<String, dynamic>)> _messageHandlers = {};

  final Set<String> _joinedRooms = {};
  bool _isConnected = false;
  bool _isAuthenticated = false;
  StreamSubscription? _subscription;

  String? _deviceCode;

  get getDeviceCode => _deviceCode;

  // Перевірка стану підключення
  bool get isConnected => _isConnected;

  // Перевірка стану авторизації
  bool get isAuthenticated => _isAuthenticated;

  void setAuthenticated(bool isAuthenticated) {
    _isAuthenticated = isAuthenticated;
  }

  // Отримання списку кімнат, до яких приєднаний клієнт
  Set<String> get joinedRooms => Set.from(_joinedRooms);

  void send(String message) {
    _channel?.sink.add(message);
  }

  Future<bool> connect(String ip, int port, String deviceCode) async {
    _deviceCode = deviceCode;
    final wsUrl = 'ws://$ip:$port/ws';
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _subscription = _channel!.stream.listen(
        (message) {
          messages.add(message);
          _handleMessage(message);
        },
        onError: _handleError,
        onDone: _handleDone,
        cancelOnError: false,
      );

      _isConnected = true;
      if (kDebugMode) {
        print('WebSocket підключено ');
      }
      onConnected?.call();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Помилка підключення до WebSocket: $e');
      }
      return false;
    }
  }

  void sendMessage(dynamic message) {
    _channel!.sink.add(jsonEncode(message));
  }

  // Приєднатися до кімнати
  Future<bool> joinRoom(String roomName) async {
    if (!_isConnected || !_isAuthenticated || _channel == null) {
      if (kDebugMode) {
        print(
          'Неможливо приєднатися до кімнати: клієнт не підключений або не авторизований',
        );
      }
      return false;
    }

    try {
      final WsMessage joinRoomMessage = WsMessage(
        type: TypeMessageWs.join_room.value,
        deviceCode: _deviceCode!,
      )..setField('room', roomName);

      _channel!.sink.add(jsonEncode(joinRoomMessage));
      _joinedRooms.add(roomName);
      if (kDebugMode) {
        print('Приєднано до кімнати: $roomName');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Помилка приєднання до кімнати $roomName: $e');
      }
      return false;
    }
  }

  // Вийти з кімнати
  Future<bool> leaveRoom(String roomName) async {
    if (!_isConnected || !_isAuthenticated || _channel == null) {
      if (kDebugMode) {
        print(
          'Неможливо вийти з кімнати: клієнт не підключений або не авторизований',
        );
      }
      return false;
    }
    if (_deviceCode == null) {
      if (kDebugMode) {
        print('Device code не авторизовано');
      }
      return false;
    }

    try {
      final WsMessage leaveRoomMessage = WsMessage(
        type: TypeMessageWs.leave_room.value,
        deviceCode: _deviceCode!,
      )..setField('room', roomName);

      _channel!.sink.add(jsonEncode(leaveRoomMessage));
      _joinedRooms.remove(roomName);
      if (kDebugMode) {
        print('Вихід з кімнати: $roomName');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Помилка виходу з кімнати $roomName: $e');
      }
      return false;
    }
  }

  // Надіслати команду керування курсором
  Future<bool> sendCursorCommand(int x, int y, int action) async {
    if (!_isConnected || !_isAuthenticated || _channel == null) {
      if (kDebugMode) {
        print(
          'Неможливо надіслати команду курсора: клієнт не підключений або не авторизований',
        );
      }
      return false;
    }

    if (!_joinedRooms.contains('control')) {
      if (kDebugMode) {
        print('Необхідно спочатку приєднатися до кімнати control');
      }
      return false;
    }

    try {
      final cursorData = {'x': x, 'y': y, 'action': action};

      final message = {
        'type': TypeMessageWs.cursor_command.value,
        'deviceCode': _deviceCode,
        'room': 'control',
        'data': cursorData,
      };

      _channel!.sink.add(jsonEncode(message));
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Помилка надсилання команди курсора: $e');
      }
      return false;
    }
  }

  // Відключення від WebSocket сервера
  Future<void> disconnect() async {
    _isConnected = false;
    _isAuthenticated = false;
    _joinedRooms.clear();

    if (_subscription != null) {
      await _subscription!.cancel();
      _subscription = null;
    }

    if (_channel != null) {
      await _channel!.sink.close(status.normalClosure);
      _channel = null;
    }

    if (kDebugMode) {
      print('WebSocket відключено');
    }
  }

  // Обробка вхідних повідомлень
  void _handleMessage(dynamic message) {
    try {
      if (message == null) return;

      final dynamic decodedMessage = jsonDecode(message.toString());
      if (decodedMessage is! Map<String, dynamic>) {
        if (kDebugMode) {
          print('Отримано некоректне повідомлення: $message');
        }
        return;
      }

      final messageType = decodedMessage['type'] as String?;
      if (messageType != null && _messageHandlers.containsKey(messageType)) {
        _messageHandlers[messageType]!(decodedMessage);
      } else {
        if (kDebugMode) {
          print('Отримано повідомлення типу $messageType: $decodedMessage');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Помилка обробки повідомлення: $e\nПовідомлення: $message');
      }
    }
  }

  // Реєстрація обробника повідомлень певного типу
  void registerHandler(
    String messageType,
    Function(Map<String, dynamic>) handler,
  ) {
    _messageHandlers[messageType] = handler;
  }

  // Видалення обробника повідомлень
  void removeHandler(String messageType) {
    _messageHandlers.remove(messageType);
  }

  // Обробка помилок WebSocket
  void _handleError(error) {
    onError?.call(error);
    if (kDebugMode) {
      print('Помилка WebSocket: $error');
    }
  }

  // Обробка закриття WebSocket
  void _handleDone() {
    if (kDebugMode) {
      print('WebSocket з\'єднання закрито');
    }
    onDisconnected?.call();
    _isConnected = false;
    _isAuthenticated = false;
    _joinedRooms.clear();
  }

  void close() {
    for (var room in _joinedRooms.toList()) {
      leaveRoom(room);
    }
    // Закрываем WebSocket соединение
    if (_channel != null) {
      _channel = null;
    }

    _isConnected = false;
    _deviceCode = null;
    _messageHandlers.clear();
    _joinedRooms.clear();
  }
}
