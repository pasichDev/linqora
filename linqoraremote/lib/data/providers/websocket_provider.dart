import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../device_info.dart';

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
  Map<String, dynamic>? systemInfo;
  StreamSubscription? _subscription;

  String? _deviceCode;

  // Перевірка стану підключення
  bool get isConnected => _isConnected;

  // Перевірка стану авторизації
  bool get isAuthenticated => _isAuthenticated;

  // Отримання списку кімнат, до яких приєднаний клієнт
  Set<String> get joinedRooms => Set.from(_joinedRooms);
  void send(String message) {
    _channel?.sink.add(message);
  }

  Future<bool> connect(String ip, int port) async {
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

  // Авторизація на сервері
  Future<bool> authenticate(String deviceCode) async {
    _deviceCode = deviceCode;
    var deviceName = await getDeviceName();
    if (!_isConnected || _channel == null) {
      if (kDebugMode) {
        print('Неможливо авторизуватися: відсутнє підключення');
      }
      return false;
    }
    // Відправляємо запит на авторизацію
    final authMessage = {
      'type': 'auth',
      'deviceCode': deviceCode,
      'data': {'deviceName': deviceName},
    };
    try {
      // Реєструємо обробник відповіді на авторизацію
      final completer = Completer<bool>();

      // Тимчасовий обробник для авторизації
      _messageHandlers['auth_response'] = (data) {
        final success = data['success'] as bool;
        if (success) {
          _isAuthenticated = true;
          systemInfo = data['systemInfo'] as Map<String, dynamic>;
          if (kDebugMode) {
            print('Авторизація успішна. Інформація про систему: $systemInfo');
          }

          // Додаємо клієнта до кімнати auth автоматично (сервер це робить)
          _joinedRooms.add('auth');

          completer.complete(true);
        } else {
          final message = data['message'] as String;
          if (kDebugMode) {
            print('Помилка авторизації: $message');
          }
          completer.complete(false);
        }

        // Видаляємо тимчасовий обробник
        _messageHandlers.remove('auth_response');
      };

      // Відправляємо повідомлення авторизації
      _channel!.sink.add(jsonEncode(authMessage));

      Timer(Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          completer.complete(false);
          _messageHandlers.remove('auth_response');
          if (kDebugMode) {
            print('Таймаут авторизації');
          }
        }
      });

      return await completer.future;
    } catch (e) {
      if (kDebugMode) {
        print('Помилка під час авторизації: $e');
      }
      return false;
    }
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
      final message = {
        'type': 'join_room',
        'deviceCode': _deviceCode,
        'room': roomName,
      };

      _channel!.sink.add(jsonEncode(message));
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

    try {
      final message = {
        'type': 'leave_room',
        'deviceCode': _deviceCode,
        'room': roomName,
      };

      _channel!.sink.add(jsonEncode(message));
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

/*
  // Надіслати команду керування курсором
  Future<bool> sendCursorCommand(int x, int y, int action) async {
    if (!_isConnected || !_isAuthenticated || _channel == null) {
      print(
        'Неможливо надіслати команду курсора: клієнт не підключений або не авторизований',
      );
      return false;
    }

    if (!_joinedRooms.contains('control')) {
      print('Необхідно спочатку приєднатися до кімнати control');
      return false;
    }

    try {
      final cursorData = {'x': x, 'y': y, 'action': action};

      final message = {
        'type': 'cursor_command',
        'deviceCode': _deviceCode,
        'room': 'control',
        'data': cursorData,
      };

      _channel!.sink.add(jsonEncode(message));
      return true;
    } catch (e) {
      print('Помилка надсилання команди курсора: $e');
      return false;
    }
  }

 */

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
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final messageType = data['type'] as String?;

      if (messageType != null && _messageHandlers.containsKey(messageType)) {
        // Викликаємо відповідний обробник
        _messageHandlers[messageType]!(data);
      } else {
        if (kDebugMode) {
          print('Отримано повідомлення типу $messageType: $data');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Помилка обробки повідомлення: $e');
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
    _channel?.sink.close();
    _channel = null;
  }
}
