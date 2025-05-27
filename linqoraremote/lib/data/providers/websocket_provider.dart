import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:linqoraremote/services/background_service.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/constants/constants.dart';
import '../../core/utils/app_logger.dart';
import '../enums/type_request_host.dart';
import '../models/discovered_service.dart';
import '../models/ws_message.dart';

enum WebSocketState { hold, connected, error, disconnected }

class WebSocketProvider {
  /// The WebSocket channel used for communication.
  /// This is initialized when a connection is established and set to `null` when disconnected.
  WebSocketChannel? _channel;

  /// A map of message handlers for processing incoming WebSocket messages.
  /// - **Key**: The message type as a `String`.
  /// - **Value**: A function that processes the message, taking a `Map<String, dynamic>` as input.
  final Map<String, Function(Map<String, dynamic>)> _messageHandlers = {};

  /// A set of room names that the client has joined.
  /// Used to track the current WebSocket rooms.
  final Set<String> _joinedRooms = {};

  /// Indicates whether the WebSocket connection is currently active.
  /// - **Default**: `false`.
  bool _isConnected = false;

  /// The subscription to the WebSocket stream for receiving messages.
  /// This is used to manage the lifecycle of the stream.
  StreamSubscription? _subscription;

  /// The interval for sending periodic ping messages to the WebSocket server.
  /// - **Default**: `50 seconds`.
  Duration _pingInterval = const Duration(seconds: 50);

  /// A timer for managing periodic ping messages.
  /// This is started when the connection is established and stopped when disconnected.
  Timer? _pingTimer;

  /// A getter to check if the WebSocket connection is active.
  /// - **Returns**: `true` if the connection is active, otherwise `false`.
  bool get isConnected => _isConnected;

  DateTime _lastPongTime = DateTime.now();

  int _consecutivePingFails = 0;

  /// This callback is used to track the status of the connection.
  Function(WebSocketState status, {String? message})? onAuthStatusChanged;
  Function(bool isDisconnect)? onDisconnectedChanger;

  Future<bool> connect(
    MdnsDevice device, {
    bool allowSelfSigned = true,
    Duration timeout = const Duration(seconds: 10),
    Duration pingInterval = const Duration(seconds: 30),
  }) async {
    _isConnected = false;
    await _cleanupExistingConnection();
    _pingInterval = pingInterval;

    final wsUrl =
        '${device.supportsTLS ? 'wss' : 'ws'}://${device.address}:${device.port}/ws';
    AppLogger.release('Connecting to $wsUrl', module: "WebSocketProvider");
    try {
      await _establishConnection(
        wsUrl,
        device.supportsTLS,
        allowSelfSigned,
      ).timeout(
        timeout,
        onTimeout: () {
          throw TimeoutException(
            'The connection has exceeded the waiting time $timeout',
          );
        },
      );

      _subscription = _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (error) {
          onAuthStatusChanged?.call(WebSocketState.error);
          _handleError(error);
        },
        onDone: () {
          _isConnected = false;
          onAuthStatusChanged?.call(WebSocketState.disconnected);
          BackgroundConnectionService.reportConnectionState(false);
          _handleDone();
        },
        cancelOnError: false,
      );

      _isConnected = true;
      onAuthStatusChanged?.call(WebSocketState.connected);

      AppLogger.release('Connected to $wsUrl', module: "WebSocketProvider");
      registerHandler('pong', _handlePongMessage);

      /// Send ping message immediately after connection
      startPingTimer(customInterval: pingInterval);
      return true;
    } catch (e) {
      await _cleanupExistingConnection();
      AppLogger.release(
        'Error connecting to WebSocket: $e',
        module: "WebSocketProvider",
      );
      onAuthStatusChanged?.call(
        WebSocketState.error,
        message: "Failed to activate multicast: $e",
      );
      return false;
    }
  }

  /// Starts a timer to send periodic ping messages to the WebSocket server.
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
    AppLogger.release(
      'PING timer is running at ${_pingInterval.inSeconds} sec intervals',
      module: "WebSocketProvider",
    );
  }

  /// Cleans up the existing WebSocket connection and its resources.
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

  /// Establishes a WebSocket connection to the specified URL.
  Future<void> _establishConnection(
    String wsUrl,
    bool supportsTLS,
    bool allowSelfSigned,
  ) async {
    if (supportsTLS) {
      try {
        await _establishTLSConnection(wsUrl, allowSelfSigned);
      } catch (e) {
        AppLogger.release(
          'TLS connection error: $e. Attempting a normal connection...',
          module: "WebSocketProvider",
        );

        await _establishStandardConnection(wsUrl);
      }
    } else {
      await _establishStandardConnection(wsUrl);
    }
  }

  /// Establishes a TLS WebSocket connection.
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
      onTimeout: () => throw TimeoutException('TLS connection timeout'),
    );

    _channel = IOWebSocketChannel(webSocket);

    AppLogger.release('TLS Connect', module: "WebSocketProvider");
  }

  /// Establishes a standard WebSocket connection.
  Future<void> _establishStandardConnection(String wsUrl) async {
    final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    await channel.ready.timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw TimeoutException('Connection timeout'),
    );
    _channel = channel;

    AppLogger.debug(
      'Connected via a standard connection',
      module: "WebSocketProvider",
    );
  }

  /// Sends a message to the WebSocket server.
  void sendMessage(dynamic message) {
    _channel!.sink.add(jsonEncode(message));
  }

  /// Sends a message to the WebSocket server with a specific type.
  Future<bool> joinRoom(String roomName) async {
    if (!isReadyForCommand()) return false;

    try {
      final WsMessage joinRoomMessage = WsMessage(
        type: TypeMessageWs.join_room.value,
      )..setField('room', roomName);

      sendMessage(joinRoomMessage.toJson());
      _joinedRooms.add(roomName);
      AppLogger.release(
        'Attached to room: $roomName',
        module: "WebSocketProvider",
      );

      return true;
    } catch (e) {
      AppLogger.release(
        'Error joining room $roomName',
        module: "WebSocketProvider",
      );
      return false;
    }
  }

  /// Leaves a room in the WebSocket server.
  Future<bool> leaveRoom(String roomName) async {
    if (!isReadyForCommand()) return false;

    try {
      final WsMessage leaveRoomMessage = WsMessage(
        type: TypeMessageWs.leave_room.value,
      )..setField('room', roomName);

      sendMessage(leaveRoomMessage.toJson());
      _joinedRooms.remove(roomName);
      AppLogger.release('Room left $roomName', module: "WebSocketProvider");
      return true;
    } catch (e) {
      AppLogger.release(
        'Error room left $roomName',
        module: "WebSocketProvider",
      );
      return false;
    }
  }

  /// Checks if the client is joined to a specific room.
  Future<bool> isJoinedRoom(String nameRoom) async {
    return _joinedRooms.contains(nameRoom);
  }

  Future<void> disconnect({bool clearHandlers = false}) async {
    _pingTimer?.cancel();
    _pingTimer = null;

    if (_isConnected && _channel != null) {
      for (var room in _joinedRooms.toList()) {
        try {
          final leaveRoomMessage = WsMessage(
            type: TypeMessageWs.leave_room.value,
          )..setField('room', room);
          sendMessage(leaveRoomMessage.toJson());
        } catch (e) {
          AppLogger.release(
            'Error when leaving room $room',
            module: "WebSocketProvider",
          );
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
        AppLogger.release(
          'Error closing WebSocket: $e',
          module: "WebSocketProvider",
        );
      }
      _channel = null;
    }

    _isConnected = false;
    _joinedRooms.clear();

    if (clearHandlers) {
      _messageHandlers.clear();
    }

    AppLogger.release('Web Socket closed', module: "WebSocketProvider");
  }

  /// Handles incoming WebSocket messages.
  void _handleMessage(dynamic message) {
    try {
      if (message == null) return;

      final dynamic decodedMessage = jsonDecode(message.toString());
      if (decodedMessage is! Map<String, dynamic>) {
        AppLogger.release(
          'Invalid message received: $message',
          module: "WebSocketProvider",
        );
        return;
      }

      final messageType = decodedMessage['type'] as String?;
      if (messageType != null && _messageHandlers.containsKey(messageType)) {
        _messageHandlers[messageType]!(decodedMessage);
        AppLogger.debug(
          'Messages of the type: $messageType: $decodedMessage',
          module: "WebSocketProvider",
        );
      } else {
        AppLogger.debug(
          'A message of the type: $messageType: $decodedMessage',
          module: "WebSocketProvider",
        );
      }
    } catch (e) {
      AppLogger.release(
        'Invalid message received: $message',
        module: "WebSocketProvider",
      );
    }
  }

  /// Checks if the client is ready to send commands.
  bool isReadyForCommand() {
    if (!_isConnected || _channel == null) {
      AppLogger.release(
        'Operation cannot be performed: the client is not connected or logged in',
        module: "WebSocketProvider",
      );
      return false;
    }
    return true;
  }

  /// Registers a message handler for a specific message type.
  void registerHandler(
    String messageType,
    Function(Map<String, dynamic>) handler,
  ) {
    _messageHandlers[messageType] = handler;
  }

  /// Removes a message handler for a specific message type.
  void removeHandler(String messageType) {
    _messageHandlers.remove(messageType);
  }

  /// Handles errors that occur during WebSocket communication.
  void _handleError(error) {
    AppLogger.release('WebSocket error', module: "WebSocketProvider");
  }

  /// Sends a ping message to the WebSocket server.
  Future<void> sendPing() async {
    if (!isConnected) {
      BackgroundConnectionService.reportConnectionState(false);
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final message = WsMessage(type: 'ping')
        ..setField('data', {'timestamp': timestamp});

      sendMessage(message.toJson());

      /// Set a timer to check for a pong response
      Timer(Duration(seconds: 10), () {
        if (_lastPongTime.millisecondsSinceEpoch < timestamp) {
          _consecutivePingFails++;

          AppLogger.debug(
            'Ping timeout, consecutive fails: $_consecutivePingFails',
            module: "WebSocketProvider",
          );

          /// Set the connection state to false if the ping fails
          BackgroundConnectionService.reportConnectionState(
            _consecutivePingFails < maxMissedPings,
            latency: null,
          );

          /// If the number of consecutive ping fails exceeds the maximum allowed,
          if (_consecutivePingFails >= maxMissedPings) {
            _handleConnectionLost();
          }
        }
      });

      AppLogger.debug(
        'Sending ping with timestamp: $timestamp',
        module: "WebSocketProvider",
      );
    } catch (e) {
      AppLogger.release('Error sending ping: $e', module: "WebSocketProvider");

      /// If an error occurs while sending the ping, set the connection state to false
      BackgroundConnectionService.reportConnectionState(false);
    }
  }

  /// Method to handle connection loss.
  void _handleConnectionLost() {
    AppLogger.release(
      'Connection lost detected, closing WebSocket',
      module: "WebSocketProvider",
    );

    _isConnected = false;

    BackgroundConnectionService.reportConnectionState(false);

    if (onDisconnectedChanger != null) {
      try {
        onDisconnectedChanger?.call(true);
      } catch (e) {
        AppLogger.release(
          'Error in onDisconnectedChanger callback: $e',
          module: "WebSocketProvider",
        );
      }
    }

    // Закрываем соединение после колбека
    disconnect(clearHandlers: false);
  }

  /// Handles the pong message received from the WebSocket server.
  void _handlePongMessage(Map<String, dynamic> data) {
    _consecutivePingFails = 0;
    _lastPongTime = DateTime.now();

    /// Calculate the latency based on the timestamp received in the pong message
    int? latency;
    if (data['data'] != null && data['data']['timestamp'] != null) {
      final timestamp = data['data']['timestamp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      latency = now - timestamp;

      AppLogger.debug(
        'Pong received, latency: $latency ms',
        module: "WebSocketProvider",
      );
    }

    BackgroundConnectionService.reportConnectionState(true, latency: latency);
  }

  /// Stops the ping timer to prevent sending further ping messages.
  void stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
    AppLogger.debug('Stop PING timer', module: "WebSocketProvider");
  }

  /// Handles the completion of the WebSocket connection.
  void _handleDone() {
    AppLogger.release(
      'WebSocket connection closed',
      module: "WebSocketProvider",
    );
    _isConnected = false;
    _joinedRooms.clear();
  }
}
