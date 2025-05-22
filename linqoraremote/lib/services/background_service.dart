import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/utils/app_logger.dart';
import '../core/utils/ping.dart';

/// Service for maintaining a connection to the host in the background when the application is minimised.
/// Provides constant communication with the server and displays notifications about the connection status.
class BackgroundConnectionService {
  static const String MESSAGE_CHECK_CONNECTION = 'check_connection';
  static const String MESSAGE_CONNECTION_LOST = 'connection_lost';

  static const String _notificationChannelId = 'linqora_connection';
  static const int _notificationId = 888;
  static const String _portName = 'linqora_background_port';

  static ReceivePort? _receivePort;
  static FlutterBackgroundService? _service;

  /// Registration of the background service
  static final List<Function(String)> _messageHandlers = [];
  static final List<Function(Map<String, dynamic>)> _dataHandlers = [];

  /// Add a message handler for the background service
  static void addMessageHandler(Function(String) handler) {
    _messageHandlers.add(handler);
  }

  /// Delete a message handler
  static void removeMessageHandler(Function(String) handler) {
    _messageHandlers.remove(handler);
  }

  /// Adds a structured data handler
  static void addDataHandler(Function(Map<String, dynamic>) handler) {
    _dataHandlers.add(handler);
  }

  /// Deletes a structured data handler
  static void removeDataHandler(Function(Map<String, dynamic>) handler) {
    _dataHandlers.remove(handler);
  }

  /// Sends a message to the background service
  static void reportConnectionState(bool isConnected, {int? latency}) {
    if (_service == null) return;

    try {
      _service!.invoke('connectionState', {
        'isConnected': isConnected,
        'latency': latency ?? 0,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      AppLogger.debug(
        'Reported connection state: $isConnected, latency: $latency',
        module: "BackgroundConnectionService",
      );
    } catch (e) {
      AppLogger.release(
        'Error reporting connection state: $e',
        module: "BackgroundConnectionService",
      );
    }
  }

  /// Initializes the background service and sets up the notification channel.
  /// Gets called when the app starts.
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();
    _service = service;
    bool isRunning = await _service!.isRunning();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _notificationChannelId,
      'Linqora Background',
      description: 'Keeps the connection with Linqora host active',
      importance: Importance.high,
      playSound: false,
      showBadge: false,
      enableVibration: false,
    );

    if (!isRunning) {
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);

      await flutterLocalNotificationsPlugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );

      /// Configure the background service
      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: false,
          isForegroundMode: true,
          notificationChannelId: _notificationChannelId,
          foregroundServiceNotificationId: _notificationId,
          autoStartOnBoot: false,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: onStart,
          onBackground: onIosBackground,
        ),
      );
    }
  }

  /// Forcefully updates the device information in the background service.
  static Future<void> forceUpdateDeviceInfo(
    String deviceName,
    String deviceAddress,
    bool isConnected,
    bool notificationsEnabled,
  ) async {
    if (_service == null || !(await _service!.isRunning())) return;

    _service!.invoke('updateDeviceInfo', {
      'deviceName': deviceName,
      'deviceAddress': deviceAddress,
      'notificationsEnabled': notificationsEnabled,
      'isConnected': isConnected,
    });
  }

  /// Starts the background service and creates a communication channel between the main app and the background service.
  static Future<bool> startService(
    String deviceName,
    String deviceAddress,
    bool isConnected,
  ) async {
    if (_service == null) {
      await initializeService();
    }

    if (_receivePort != null) {
      _receivePort!.close();
      IsolateNameServer.removePortNameMapping(_portName);
    }

    _receivePort = ReceivePort();
    IsolateNameServer.registerPortWithName(_receivePort!.sendPort, _portName);

    _receivePort!.listen((message) {
      AppLogger.debug(
        'Message: $message',
        module: "BackgroundConnectionService",
      );

      if (message is String) {
        for (final handler in List<Function(String)>.from(_messageHandlers)) {
          handler(message);
        }
      } else if (message is Map<String, dynamic>) {
        for (final handler in List<Function(Map<String, dynamic>)>.from(
          _dataHandlers,
        )) {
          handler(message);
        }
      }
    });

    await _service!.startService();

    return true;
  }

  /// Stops the background service and closes the communication channel.
  /// If `isPause` is true, timers inside the service are stopped but the service continues to run.
  /// If `isPause` is false, the service is completely stopped.
  static Future<void> stopService({bool isPause = false}) async {
    try {
      AppLogger.release(
        isPause
            ? 'Pausing background service...'
            : 'Stopping background service...',
        module: "BackgroundConnectionService",
      );

      if (_service != null && await _service!.isRunning()) {
        if (isPause) {
          _service!.invoke('pauseService');

          AppLogger.release(
            'Background service paused (timers stopped)',
            module: "BackgroundConnectionService",
          );
        } else {
          await Future.delayed(Duration(milliseconds: 500));
          _service!.invoke('stopService');

          if (_receivePort != null) {
            _receivePort!.close();
            IsolateNameServer.removePortNameMapping(_portName);
            _receivePort = null;
          }

          _messageHandlers.clear();
          _dataHandlers.clear();

          AppLogger.release(
            'Background service stopped completely',
            module: "BackgroundConnectionService",
          );
        }
      }
    } catch (e) {
      AppLogger.release(
        'Error ${isPause ? 'pausing' : 'stopping'} background service: $e',
        module: "BackgroundConnectionService",
      );
    }
  }

  /// Checks if the background service is running.
  static Future<bool> isRunning() async {
    if (_service == null) {
      return false;
    }
    return await _service!.isRunning();
  }
}

/// Point of entry for the background service.
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  String deviceName = 'Unknown Device';
  String deviceAddress = '';
  bool isConnected = true;
  bool notificationsEnabled = false;

  /// Maximum number of missed pings before considering the connection lost
  int lastPongTimestamp = DateTime.now().millisecondsSinceEpoch;
  int consecutivePingFails = 0;

  Timer? connectionCheckTimer;
  Timer? statusUpdateTimer;

  final sendPort = IsolateNameServer.lookupPortByName(
    'linqora_background_port',
  );

  /// Maximum number of missed pings before considering the connection lost
  void updateNotification() {
    if (service is AndroidServiceInstance && notificationsEnabled) {
      service.setForegroundNotificationInfo(
        title: 'Linqora Remote',
        content:
            isConnected
                ? "Connected to $deviceName ($deviceAddress)"
                : "Disconnected from $deviceName ($deviceAddress)",
      );
    }
  }

  service.on('pauseService').listen((event) {
    AppLogger.debug(
      'Received pause service command - stopping timers',
      module: "BackgroundService",
    );

    /// Stop all timers
    connectionCheckTimer?.cancel();
    statusUpdateTimer?.cancel();

    if (sendPort != null) {
      sendPort.send('service_paused');
    }
  });

  /// Stop the background service
  service.on('stopService').listen((event) {
    AppLogger.debug(
      'Received stop service command',
      module: "BackgroundService",
    );

    /// Stop all timers
    connectionCheckTimer?.cancel();
    statusUpdateTimer?.cancel();

    service.stopSelf();
  });

  /// Update the notification with the current connection status
  service.on('updateDeviceInfo').listen((event) {
    if (event != null) {
      deviceName = event['deviceName'] ?? deviceName;
      deviceAddress = event['deviceAddress'] ?? deviceAddress;
      isConnected = event['isConnected'] ?? isConnected;
      notificationsEnabled = event['notificationsEnabled'] ?? isConnected;

      updateNotification();

      if (sendPort != null) {
        sendPort.send('deviceInfoUpdated');
      }
    }
  });

  /// Update the notification with the current connection status
  service.on('connectionState').listen((event) {
    if (event != null) {
      bool newConnectionState = event['isConnected'] ?? isConnected;

      /// Elsewhere in the code, we assume that the connection is lost
      if (newConnectionState != isConnected) {
        AppLogger.debug(
          'Connection state changed: $isConnected -> $newConnectionState',
          module: "BackgroundService",
        );

        isConnected = newConnectionState;
        lastPongTimestamp = DateTime.now().millisecondsSinceEpoch;
        consecutivePingFails = 0;

        updateNotification();

        /// Send a message to the main isolate
        if (sendPort != null && !isConnected) {
          sendPort.send(BackgroundConnectionService.MESSAGE_CONNECTION_LOST);
        }
      } else if (isConnected) {
        /// If the connection is still active, update the last pong timestamp
        lastPongTimestamp = DateTime.now().millisecondsSinceEpoch;
        consecutivePingFails = 0;
      }
    }
  });

  /// Periodically check the connection status
  connectionCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) {
    if (sendPort != null) {
      /// Request a connection check
      sendPort.send(BackgroundConnectionService.MESSAGE_CHECK_CONNECTION);

      /// Check if the connection is still active
      if (isConnected) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final elapsed = now - lastPongTimestamp;

        /// Elapsed time since the last pong
        if (elapsed > 30000) {
          consecutivePingFails++;

          AppLogger.debug(
            'Background service timeout check: $consecutivePingFails, elapsed: ${elapsed / 1000}s',
            module: "BackgroundService",
          );

          if (consecutivePingFails >= maxMissedPings) {
            isConnected = false;
            updateNotification();
            sendPort.send(BackgroundConnectionService.MESSAGE_CONNECTION_LOST);
          }
        }
      }
    }
  });

  /// Periodically send the current connection status
  statusUpdateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
    service.invoke('update', {
      'isRunning': true,
      'timestamp': DateTime.now().toIso8601String(),
      'deviceName': deviceName,
      'isConnected': isConnected,
    });
  });
}

/// Handler for iOS background execution.
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}
