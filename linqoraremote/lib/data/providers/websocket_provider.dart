import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../enums/type_messages_ws.dart';
import '../models/discovered_service.dart';
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

  // Перевірка стану підключення
  bool get isConnected => _isConnected;

  // Перевірка стану авторизації
  bool get isAuthenticated => _isAuthenticated;

  void setAuthenticated(bool isAuthenticated) {
    _isAuthenticated = isAuthenticated;
  }

  // Отримання списку кімнат, до яких приєднаний клієнт
  Set<String> get joinedRooms => Set.from(_joinedRooms);

  // Добавляем метод для отправки JSON объекта
  void sendJson(Map<String, dynamic> message) {
    if (kDebugMode) {
      print('Sending message: ${jsonEncode(message)}');
    }
    send(jsonEncode(message));
  }

  // Обновляем метод send с дополнительным логированием
  void send(String message) {
    if (_channel != null) {
      if (kDebugMode) {
        print('WebSocket message sent');
      }
      _channel!.sink.add(message);
    } else {
      if (kDebugMode) {
        print('WebSocket not connected, cannot send message');
      }
    }
  }

  Future<bool> connect(
    DiscoveredService device, {
    bool allowSelfSigned = true,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // 1. Сбрасываем статус соединения
    _isConnected = false;

    // 2. Корректно закрываем предыдущее соединение
    await _cleanupExistingConnection();

    final protocol = device.supportsTLS ? 'wss' : 'ws';
    final wsUrl = '$protocol://${device.address}:${device.port}/ws';

    if (kDebugMode) {
      print('Підключення до $wsUrl');
    }

    try {
      // 3. Используем таймаут для подключения
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

      // 4. Настраиваем обработчики сообщений
      _subscription = _channel!.stream.listen(
        (message) {
          messages.add(message);
          _handleMessage(message);
        },
        onError: (error) {
          _isConnected = false; // Сброс при ошибке
          _handleError(error);
        },
        onDone: () {
          _isConnected = false; // Сброс при закрытии
          _handleDone();
        },
        cancelOnError: false,
      );

      // 5. Устанавливаем флаг только при успешном соединении
      _isConnected = true;
      onConnected?.call();

      if (kDebugMode) {
        print('WebSocket підключено');
      }
      return true;
    } catch (e) {
      // 6. Обрабатываем любую ошибку, очищаем ресурсы
      await _cleanupExistingConnection();

      if (kDebugMode) {
        print('Помилка підключення до WebSocket: $e');
      }
      onError?.call(e);
      return false;
    }
  }

  // Вспомогательные методы для упрощения основного кода:

  // Очистка предыдущего соединения
  Future<void> _cleanupExistingConnection() async {
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
    // Проверяем доступность хоста перед WebSocket подключением
    final uri = Uri.parse(wsUrl);
    try {
      // Быстрая проверка доступности хоста - таймаут 2 секунды
      final socket = await Socket.connect(
        uri.host,
        uri.port,
        timeout: const Duration(seconds: 2),
      );
      await socket.close();
    } catch (e) {
      // Если хост недоступен, сразу выбрасываем исключение
      if (kDebugMode) {
        print('Хост недоступен: ${uri.host}:${uri.port}');
      }
      throw SocketException('Хост недоступен');
    }

    // Продолжаем только если хост доступен
    if (supportsTLS) {
      try {
        final client =
            HttpClient()
              ..badCertificateCallback = (_, __, ___) => allowSelfSigned;

        // Используем таймаут для TLS подключения
        final webSocket = await WebSocket.connect(
          wsUrl,
          customClient: client,
        ).timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw TimeoutException('Таймаут TLS подключения'),
        );

        _channel = IOWebSocketChannel(webSocket);

        if (kDebugMode) {
          print('Підключено через самопідписаний TLS сертифікат');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Помилка підключення через самопідписаний сертифікат: $e');
          print('Пробуємо звичайне підключення...');
        }

        // Используем таймаут для обычного подключения
        final completer = Completer<WebSocketChannel>();

        // Запускаем таймер для ограничения времени ожидания
        final timer = Timer(const Duration(seconds: 5), () {
          if (!completer.isCompleted) {
            completer.completeError(
              TimeoutException('Таймаут обычного подключения'),
            );
          }
        });

        // Запускаем подключение в отдельной зоне
        try {
          final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
          // Ждем событие открытия соединения или ошибки
          await channel.ready.timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw TimeoutException('Channel ready timeout'),
          );

          timer.cancel();
          if (!completer.isCompleted) {
            completer.complete(channel);
          }
        } catch (e) {
          timer.cancel();
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        }

        _channel = await completer.future;
      }
    } else {
      // Обычное подключение с таймаутом
      final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await channel.ready.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('Таймаут обычного подключения'),
      );
      _channel = channel;
    }
  }

  void sendMessage(dynamic message) {
    _channel!.sink.add(jsonEncode(message));
  }

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

    try {
      final WsMessage leaveRoomMessage = WsMessage(
        type: TypeMessageWs.leave_room.value,
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

  // Отправить команду управления мультимедиа
  Future<bool> sendMediaCommand(int action, int value) async {
    if (!_isConnected || !_isAuthenticated || _channel == null) {
      if (kDebugMode) {
        print(
          'Неможливо надіслати медіа команду: клієнт не підключений або не авторизований',
        );
      }
      return false;
    }

    if (!_joinedRooms.contains(TypeMessageWs.media.value)) {
      if (kDebugMode) {
        print(
          'Необхідно спочатку приєднатися до кімнати ${TypeMessageWs.media.value}',
        );
      }
      return false;
    }

    try {
      final mediaData = {'action': action, 'value': value};
      final message = {
        'type': TypeMessageWs.media.value,
        'room': TypeMessageWs.media.value,
        'data': mediaData,
      };

      _channel!.sink.add(jsonEncode(message));
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Помилка відправки медіа команди: $e');
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
    if (_channel != null) {
      _channel = null;
    }

    _isConnected = false;
    _messageHandlers.clear();
    _joinedRooms.clear();
  }
}
