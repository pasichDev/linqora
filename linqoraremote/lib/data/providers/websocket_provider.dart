import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../enums/type_messages_ws.dart';
import '../models/discovered_service.dart';
import '../models/ws_message.dart';

class WebSocketProvider {
  WebSocketChannel? _channel;

  Function()? onConnected;
  Function()? onDisconnected;
  Function(Object error)? onError;

  final Map<String, Function(Map<String, dynamic>)> _messageHandlers = {};
  final Set<String> _joinedRooms = {};
  bool _isConnected = false;
  bool _isAuthenticated = false;
  StreamSubscription? _subscription;
  Duration _pingInterval = const Duration(seconds: 50);
  Timer? _pingTimer;

  // Перевірка стану підключення
  bool get isConnected => _isConnected;

  // Перевірка стану авторизації
  bool get isAuthenticated => _isAuthenticated;

  // Отримання списку кімнат, до яких приєднаний клієнт
  Set<String> get joinedRooms => Set.from(_joinedRooms);

  Future<bool> connect(
    DiscoveredService device, {
    bool allowSelfSigned = true,
    Duration timeout = const Duration(seconds: 10),
    Duration pingInterval = const Duration(seconds: 30),
  }) async {
    _isConnected = false;
    await _cleanupExistingConnection();
    _pingInterval = pingInterval;

    final protocol = device.supportsTLS ? 'wss' : 'ws';
    final wsUrl = '$protocol://${device.address}:${device.port}/ws';

    if (kDebugMode) {
      print('Підключення до $wsUrl');
    }

    try {
      await _establishConnection(
        wsUrl,
        device.supportsTLS,
        allowSelfSigned,
      ).timeout(
        timeout,
        onTimeout: () {
          throw TimeoutException(
            'Підключення перевищило час очікування $timeout',
          );
        },
      );

      _subscription = _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (error) {
          _isConnected = false;
          _handleError(error);
        },
        onDone: () {
          _isConnected = false;
          _handleDone();
        },
        cancelOnError: false,
      );

      _isConnected = true;
      onConnected?.call();

      if (kDebugMode) {
        print('WebSocket підключено');
      }
      return true;
    } catch (e) {
      await _cleanupExistingConnection();

      if (kDebugMode) {
        print('Помилка підключення до WebSocket: $e');
      }
      onError?.call(e);
      return false;
    }
  }

  //Метод для запуска периодических ping сообщений
  void startPingTimer({Duration? customInterval}) {
    _pingTimer?.cancel();
    _pingInterval = customInterval ?? _pingInterval;
    _pingTimer = Timer.periodic(_pingInterval, (timer) {
      if (!_isConnected || _channel == null) {
        timer.cancel();
        return;
      }
      sendPing();
    });

    if (kDebugMode) {
      print('PING таймер запущен с интервалом ${_pingInterval.inSeconds} сек');
    }
  }

  void stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
    if (kDebugMode) {
      print('PING таймер остановлен');
    }
  }

  Future<void> sendPing() async {
    if (!isConnected) return;
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final message = WsMessage(type: 'ping')
        ..setField('data', {'timestamp': timestamp});
      sendMessage(message.toJson());

      if (kDebugMode) {
        print('Sending ping with timestamp: $timestamp');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending ping: $e');
      }
    }
  }

  // Обновляем метод cleanup для отмены ping таймера
  Future<void> _cleanupExistingConnection() async {
    _pingTimer?.cancel();
    _pingTimer = null;

    if (_subscription != null) {
      await _subscription!.cancel();
      _subscription = null;
    }

    if (_channel != null) {
      await _channel!.sink.close(status.normalClosure);
      _channel = null;
    }
  }

  Future<void> _establishConnection(
    String wsUrl,
    bool supportsTLS,
    bool allowSelfSigned,
  ) async {
    if (supportsTLS) {
      try {
        await _establishTLSConnection(wsUrl, allowSelfSigned);
      } catch (e) {
        if (kDebugMode) {
          print(
            'Помилка TLS підключення: $e. Спроба звичайного підключення...',
          );
        }
        await _establishStandardConnection(wsUrl);
      }
    } else {
      await _establishStandardConnection(wsUrl);
    }
  }

  Future<void> _establishTLSConnection(
    String wsUrl,
    bool allowSelfSigned,
  ) async {
    final client =
        HttpClient()..badCertificateCallback = (_, __, ___) => allowSelfSigned;

    final webSocket = await WebSocket.connect(
      wsUrl,
      customClient: client,
    ).timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw TimeoutException('Таймаут TLS підключення'),
    );

    _channel = IOWebSocketChannel(webSocket);

    if (kDebugMode) {
      print('Підключено через TLS');
    }
  }

  Future<void> _establishStandardConnection(String wsUrl) async {
    final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    await channel.ready.timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw TimeoutException('Таймаут підключення'),
    );
    _channel = channel;

    if (kDebugMode) {
      print('Підключено через звичайне з\'єднання');
    }
  }

  void sendMessage(dynamic message) {
    _channel!.sink.add(jsonEncode(message));
  }

  Future<bool> joinRoom(String roomName) async {
    if (!isReadyForCommand()) return false;

    try {
      final WsMessage joinRoomMessage = WsMessage(
        type: TypeMessageWs.join_room.value,
      )..setField('room', roomName);

      sendMessage(joinRoomMessage.toJson());
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
    if (!isReadyForCommand()) return false;

    try {
      final WsMessage leaveRoomMessage = WsMessage(
        type: TypeMessageWs.leave_room.value,
      )..setField('room', roomName);

      sendMessage(leaveRoomMessage.toJson());
      _joinedRooms.remove(roomName);
      if (kDebugMode) {
        print('Залишено кімнату: $roomName');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Помилка виходу з кімнати $roomName: $e');
      }
      return false;
    }
  }

  Future<bool> isJoinedRoom(String nameRoom) async {
    return _joinedRooms.contains(nameRoom);
  }

  Future<void> disconnect({bool clearHandlers = false}) async {
    _pingTimer?.cancel();
    _pingTimer = null;

    if (_isConnected && _isAuthenticated && _channel != null) {
      for (var room in _joinedRooms.toList()) {
        try {
          final leaveRoomMessage = WsMessage(
            type: TypeMessageWs.leave_room.value,
          )..setField('room', room);
          sendMessage(leaveRoomMessage.toJson());
        } catch (e) {
          if (kDebugMode) {
            print('Помилка при виході з кімнати $room: $e');
          }
        }
      }
    }

    if (_subscription != null) {
      await _subscription!.cancel();
      _subscription = null;
    }
    if (_channel != null) {
      try {
        await _channel!.sink.close(status.normalClosure);
      } catch (e) {
        if (kDebugMode) {
          print('Помилка при закритті WebSocket: $e');
        }
      }
      _channel = null;
    }

    _isConnected = false;
    _isAuthenticated = false;
    _joinedRooms.clear();

    if (clearHandlers) {
      _messageHandlers.clear();
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

  bool isReadyForCommand() {
    if (!_isConnected || !_isAuthenticated || _channel == null) {
      if (kDebugMode) {
        print(
          'Операція не може бути виконана: клієнт не підключений або не авторизований',
        );
      }
      return false;
    }
    return true;
  }

  // Реєстрація обробника повідомлень певного типу
  void registerHandler(
    String messageType,
    Function(Map<String, dynamic>) handler,
  ) {
    _messageHandlers[messageType] = handler;
  }

  void setAuthenticated(bool isAuthenticated) {
    _isAuthenticated = isAuthenticated;
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
    _isConnected = false;
    _isAuthenticated = false;
    _joinedRooms.clear();
    onDisconnected?.call();
  }

  void close() {
    disconnect(clearHandlers: true);
  }
}
