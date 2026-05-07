import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:linqoraremote/services/background_service.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/constants/constants.dart';
import '../../core/utils/app_logger.dart';
import '../enums/type_request_host.dart';
import '../models/discovered_service.dart';
import '../models/ws_message.dart';
import '../services/certificate_service.dart';

enum WebSocketState { hold, connected, error, disconnected }

enum ReconnectState { idle, connecting, connected, reconnecting, failed }

class WebSocketProvider {
  WebSocketChannel? _channel;

  final Map<String, Function(Map<String, dynamic>)> _messageHandlers = {};

  final Set<String> _joinedRooms = {};

  bool _isConnected = false;

  StreamSubscription? _subscription;

  Duration _pingInterval = const Duration(seconds: 50);

  Timer? _pingTimer;

  bool get isConnected => _isConnected;

  DateTime _lastPongTime = DateTime.now();

  int _consecutivePingFails = 0;

  Timer? _pongCheckTimer;

  // ---------------------------------------------------------------------------
  // Reconnect state
  // ---------------------------------------------------------------------------

  static const _reconnectDelays = [1, 2, 4, 8, 16];

  MdnsDevice? _reconnectDevice;
  bool _lastAllowSelfSigned = false;

  /// Set to true when the user explicitly disconnects so auto-reconnect stops.
  bool _userDisconnected = false;

  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;
  Timer? _reconnectCountdownTimer;

  /// Snapshot of rooms to re-join after a successful reconnect.
  Set<String> _reconnectRooms = {};

  /// Observable reconnect state for UI consumption.
  final reconnectState = Rx<ReconnectState>(ReconnectState.idle);

  /// Seconds remaining until the next reconnect attempt.
  final reconnectSecondsLeft = RxInt(0);

  // ---------------------------------------------------------------------------

  Function(WebSocketState status, {String? message})? onAuthStatusChanged;
  Function(bool isDisconnect)? onDisconnectedChanger;

  Future<bool> connect(
    MdnsDevice device, {
    bool allowSelfSigned = true,
    Duration timeout = const Duration(seconds: 10),
    Duration pingInterval = const Duration(seconds: 30),
  }) async {
    _userDisconnected = false;
    _isConnected = false;
    await _cleanupExistingConnection();
    _pingInterval = pingInterval;
    _reconnectDevice = device;
    _lastAllowSelfSigned = allowSelfSigned;

    final wsUrl =
        '${device.supportsTLS ? 'wss' : 'ws'}://${device.address}:${device.port}/ws';
    AppLogger.release('Connecting to $wsUrl', module: "WebSocketProvider");
    reconnectState.value = ReconnectState.connecting;

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

      _setupStreamListeners();

      _isConnected = true;
      _reconnectAttempt = 0;
      reconnectState.value = ReconnectState.connected;
      onAuthStatusChanged?.call(WebSocketState.connected);

      AppLogger.release('Connected to $wsUrl', module: "WebSocketProvider");
      registerHandler('pong', _handlePongMessage);
      startPingTimer(customInterval: pingInterval);
      return true;
    } catch (e) {
      await _cleanupExistingConnection();
      reconnectState.value = ReconnectState.idle;
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

  /// Attaches stream listeners to the current [_channel].
  /// Extracted so both [connect] and [_performReconnect] share the same wiring.
  void _setupStreamListeners() {
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

  /// Cleans up the current WebSocket connection and its I/O resources.
  /// Does NOT touch the reconnect timers.
  Future<void> _cleanupExistingConnection() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    _pongCheckTimer?.cancel();
    _pongCheckTimer = null;

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
        AppLogger.release(
          'TLS connection error: $e. Attempting a normal connection...',
          module: "WebSocketProvider",
        );
        // Fallback to non-TLS connection
        final fallbackUrl = wsUrl.replaceFirst('wss://', 'ws://');
        await _establishStandardConnection(fallbackUrl);
      }
    } else {
      await _establishStandardConnection(wsUrl);
    }
  }

  Future<void> _establishTLSConnection(
    String wsUrl,
    bool allowSelfSigned,
  ) async {
    final client = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        if (!allowSelfSigned) return false;
        // TOFU pinning: accept on first connection, reject if fingerprint changes.
        return CertificateService.verifyOrPin(cert, host);
      };

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

  Future<bool> isJoinedRoom(String nameRoom) async {
    return _joinedRooms.contains(nameRoom);
  }

  Future<void> disconnect({bool clearHandlers = false}) async {
    _userDisconnected = true;
    _cancelReconnect();

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
    reconnectState.value = ReconnectState.idle;

    if (clearHandlers) {
      _messageHandlers.clear();
    }

    AppLogger.release('Web Socket closed', module: "WebSocketProvider");
  }

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

  void registerHandler(
    String messageType,
    Function(Map<String, dynamic>) handler,
  ) {
    _messageHandlers[messageType] = handler;
  }

  void removeHandler(String messageType) {
    _messageHandlers.remove(messageType);
  }

  void _handleError(error) {
    AppLogger.release('WebSocket error', module: "WebSocketProvider");
  }

  Future<void> sendPing() async {
    if (!isConnected) {
      BackgroundConnectionService.reportConnectionState(false);
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final message = WsMessage(type: 'ping')
        ..setField('data', {'timestamp': timestamp});

      sendMessage(message.toJson());

      _pongCheckTimer?.cancel();
      _pongCheckTimer = Timer(const Duration(seconds: 10), () {
        if (_lastPongTime.millisecondsSinceEpoch < timestamp) {
          _consecutivePingFails++;

          AppLogger.debug(
            'Ping timeout, consecutive fails: $_consecutivePingFails',
            module: "WebSocketProvider",
          );

          BackgroundConnectionService.reportConnectionState(
            _consecutivePingFails < maxMissedPings,
            latency: null,
          );

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
      BackgroundConnectionService.reportConnectionState(false);
    }
  }

  void _handleConnectionLost() {
    AppLogger.release(
      'Connection lost detected, closing WebSocket',
      module: "WebSocketProvider",
    );

    _isConnected = false;
    BackgroundConnectionService.reportConnectionState(false);

    // Snapshot rooms for re-joining after reconnect.
    _reconnectRooms = Set<String>.from(_joinedRooms);

    _cleanupExistingConnection().then((_) {
      if (!_userDisconnected) {
        _scheduleReconnect();
      } else {
        onDisconnectedChanger?.call(true);
      }
    });
  }

  void _handlePongMessage(Map<String, dynamic> data) {
    _consecutivePingFails = 0;
    _lastPongTime = DateTime.now();

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

  void stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
    AppLogger.debug('Stop PING timer', module: "WebSocketProvider");
  }

  void _handleDone() {
    AppLogger.release(
      'WebSocket connection closed',
      module: "WebSocketProvider",
    );
    _isConnected = false;
    // Snapshot rooms so they can be re-joined after reconnect.
    _reconnectRooms = Set<String>.from(_joinedRooms);
    _joinedRooms.clear();

    if (!_userDisconnected) {
      _scheduleReconnect();
    }
  }

  // ---------------------------------------------------------------------------
  // Reconnect logic
  // ---------------------------------------------------------------------------

  /// Schedules the next reconnect attempt using exponential backoff.
  void _scheduleReconnect() {
    if (_userDisconnected || _reconnectDevice == null) return;

    if (_reconnectAttempt >= _reconnectDelays.length) {
      reconnectState.value = ReconnectState.failed;
      AppLogger.release(
        'All reconnect attempts exhausted',
        module: "WebSocketProvider",
      );
      onDisconnectedChanger?.call(true);
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectCountdownTimer?.cancel();

    final delay = _reconnectDelays[_reconnectAttempt];
    _reconnectAttempt++;

    reconnectSecondsLeft.value = delay;
    reconnectState.value = ReconnectState.reconnecting;

    AppLogger.release(
      'Reconnect attempt $_reconnectAttempt in ${delay}s',
      module: "WebSocketProvider",
    );

    _reconnectCountdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (reconnectSecondsLeft.value > 0) {
        reconnectSecondsLeft.value--;
      }
      if (reconnectSecondsLeft.value <= 0) t.cancel();
    });

    _reconnectTimer = Timer(Duration(seconds: delay), () {
      _reconnectCountdownTimer?.cancel();
      if (_userDisconnected || _reconnectDevice == null) return;
      reconnectState.value = ReconnectState.connecting;
      _performReconnect();
    });
  }

  /// Attempts to re-establish the WebSocket connection and re-join rooms.
  Future<void> _performReconnect() async {
    if (_userDisconnected || _reconnectDevice == null) return;

    final device = _reconnectDevice!;
    final roomsToRejoin = Set<String>.from(
      _reconnectRooms.isNotEmpty ? _reconnectRooms : _joinedRooms,
    );

    final wsUrl =
        '${device.supportsTLS ? 'wss' : 'ws'}://${device.address}:${device.port}/ws';
    AppLogger.release('Reconnecting to $wsUrl', module: "WebSocketProvider");

    try {
      await _cleanupExistingConnection();
      await _establishConnection(
        wsUrl,
        device.supportsTLS,
        _lastAllowSelfSigned,
      ).timeout(const Duration(seconds: 10));

      _setupStreamListeners();

      _isConnected = true;
      _reconnectAttempt = 0;
      reconnectState.value = ReconnectState.connected;

      registerHandler('pong', _handlePongMessage);
      startPingTimer(customInterval: _pingInterval);

      // Re-join rooms that were active before the disconnect.
      for (final room in roomsToRejoin) {
        _joinedRooms.add(room);
        final msg = WsMessage(type: TypeMessageWs.join_room.value)
          ..setField('room', room);
        sendMessage(msg.toJson());
        AppLogger.release(
          'Re-joined room after reconnect: $room',
          module: "WebSocketProvider",
        );
      }
      _reconnectRooms.clear();

      AppLogger.release('Reconnected successfully', module: "WebSocketProvider");
    } catch (e) {
      AppLogger.release(
        'Reconnect attempt failed: $e',
        module: "WebSocketProvider",
      );
      await _cleanupExistingConnection();
      _scheduleReconnect();
    }
  }

  /// Cancels any in-progress reconnect timers without altering [_userDisconnected].
  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectCountdownTimer?.cancel();
    _reconnectCountdownTimer = null;
    reconnectSecondsLeft.value = 0;
  }

  /// Resets the reconnect attempt counter and immediately tries again.
  /// Call this when the app returns to the foreground after a [ReconnectState.failed].
  void retryReconnect() {
    if (_reconnectDevice == null) return;
    _reconnectAttempt = 0;
    _userDisconnected = false;
    _scheduleReconnect();
  }
}
