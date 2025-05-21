import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/utils/ping.dart';

/// Служба для підтримки з'єднання з хостом у фоновому режимі, коли додаток згорнутий.
/// Забезпечує постійний зв'язок з сервером та відображення сповіщень про статус з'єднання.
class BackgroundConnectionService {
  static const String MESSAGE_CHECK_CONNECTION = 'check_connection';
  static const String MESSAGE_CONNECTION_LOST = 'connection_lost';

  static const String _notificationChannelId = 'linqora_connection';
  static const int _notificationId = 888;
  static const String _portName = 'linqora_background_port';

  static ReceivePort? _receivePort;
  static FlutterBackgroundService? _service;

  // Регистрация обработчиков сообщений
  static final List<Function(String)> _messageHandlers = [];
  static final List<Function(Map<String, dynamic>)> _dataHandlers = [];

  /// Добавляет обработчик для текстовых сообщений от фонового сервиса
  static void addMessageHandler(Function(String) handler) {
    _messageHandlers.add(handler);
  }

  /// Удаляет обработчик сообщений
  static void removeMessageHandler(Function(String) handler) {
    _messageHandlers.remove(handler);
  }

  /// Добавляет обработчик для структурированных данных от фонового сервиса
  static void addDataHandler(Function(Map<String, dynamic>) handler) {
    _dataHandlers.add(handler);
  }

  /// Удаляет обработчик структурированных данных
  static void removeDataHandler(Function(Map<String, dynamic>) handler) {
    _dataHandlers.remove(handler);
  }

  /// Сообщает фоновому сервису о состоянии соединения
  static void reportConnectionState(bool isConnected, {int? latency}) {
    if (_service == null) return;

    try {
      _service!.invoke('connectionState', {
        'isConnected': isConnected,
        'latency': latency ?? 0,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      if (kDebugMode) {
        print(
          '[Main] Reported connection state: $isConnected, latency: $latency',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('[Main] Error reporting connection state: $e');
      }
    }
  }

  /// Ініціалізує фоновий сервіс та налаштовує канали сповіщень.
  /// Викликається один раз при запуску додатка.
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();
    _service = service;

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _notificationChannelId,
      'Linqora Background',
      description: 'Keeps the connection with Linqora host active',
      importance: Importance.high,
      playSound: false,
      showBadge: false,
      enableVibration: false,
    );

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

    // Передаем в сервис информацию о том, включены ли уведомления
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

  /// Принудительно обновляет информацию об устройстве
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

  /// Запускає фоновий сервіс із вказаними параметрами підключення.
  /// Створює канал зв'язку між основним додатком та фоновою службою.
  static Future<bool> startService(
    String deviceName,
    String deviceAddress,
    bool isConnected,
  ) async {
    if (_service == null) {
      await initializeService();
    }

    // Создаем канал для обмена данными между фоновым сервисом и приложением
    if (_receivePort != null) {
      _receivePort!.close();
      IsolateNameServer.removePortNameMapping(_portName);
    }

    _receivePort = ReceivePort();
    IsolateNameServer.registerPortWithName(_receivePort!.sendPort, _portName);

    // Настраиваем обработчик сообщений от фонового сервиса
    _receivePort!.listen((message) {
      if (kDebugMode) {
        print('Сообщение от фонового сервиса: $message');
      }

      // Обрабатываем сообщение
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

    // Запускаем фоновый сервис
    await _service!.startService();

    return true;
  }

  /// Зупиняє фоновий сервіс та звільняє використані ресурси.
  /// Викликається при закритті додатка або за вимогою користувача.
  static Future<void> stopService() async {
    if (_service != null) {
      _service!.invoke('stopService');
    }

    if (_receivePort != null) {
      _receivePort!.close();
      IsolateNameServer.removePortNameMapping(_portName);
      _receivePort = null;
    }

    // Очищаем все обработчики сообщений
    _messageHandlers.clear();
    _dataHandlers.clear();
  }

  /// Перевіряє, чи активний фоновий сервіс у даний момент.
  static Future<bool> isRunning() async {
    if (_service == null) {
      return false;
    }
    return await _service!.isRunning();
  }
}

/// Точка входу для фонового сервісу.
/// Виконується в окремому ізоляті та підтримує з'єднання з сервером.
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  String deviceName = 'Неизвестное устройство';
  String deviceAddress = '';
  bool isConnected = true;
  bool notificationsEnabled = false;

  // Отслеживание последнего времени PONG
  int lastPongTimestamp = DateTime.now().millisecondsSinceEpoch;
  int consecutivePingFails = 0;

  final sendPort = IsolateNameServer.lookupPortByName(
    'linqora_background_port',
  );

  // Удобная функция для обновления уведомлений
  void updateNotification() {
    if (service is AndroidServiceInstance && notificationsEnabled) {
      service.setForegroundNotificationInfo(
        title: 'Linqora Remote ${isConnected ? 'подключен' : 'отключен'}',
        content:
            isConnected
                ? 'Подключено к $deviceName ($deviceAddress)'
                : 'Соединение с $deviceName потеряно',
      );
    }
  }

  // Обработчик обновления информации об устройстве
  service.on('updateDeviceInfo').listen((event) {
    if (event != null) {
      deviceName = event['deviceName'] ?? deviceName;
      deviceAddress = event['deviceAddress'] ?? deviceAddress;
      isConnected = event['isConnected'] ?? isConnected;
      notificationsEnabled = event['notificationsEnabled'] ?? isConnected;

      // Обновляем уведомление
      updateNotification();

      if (sendPort != null) {
        sendPort.send('deviceInfoUpdated');
      }
    }
  });

  // Обработчик статуса соединения из основного приложения
  service.on('connectionState').listen((event) {
    if (event != null) {
      bool newConnectionState = event['isConnected'] ?? isConnected;

      // Если статус соединения изменился
      if (newConnectionState != isConnected) {
        isConnected = newConnectionState;

        // Обновляем уведомление
        updateNotification();

        // Сбрасываем счетчик неудачных пингов при восстановлении соединения
        if (isConnected) {
          consecutivePingFails = 0;
        }
      }

      // Обновляем timestamp последнего PONG
      if (isConnected && event['timestamp'] != null) {
        lastPongTimestamp = event['timestamp'];
      }
    }
  });

  // Обработчик остановки сервиса
  service.on('stopService').listen((event) {
    if (sendPort != null) {
      sendPort.send('stopping');
    }
    service.stopSelf();
  });

  // Запускаем периодическую проверку соединения
  Timer.periodic(const Duration(seconds: 30), (_) {
    if (sendPort != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsed = now - lastPongTimestamp;

      // Если прошло более 35 секунд с последнего PONG и соединение считается активным
      if (elapsed > 35000 && isConnected) {
        // Увеличиваем счетчик неудачных пингов
        consecutivePingFails++;

        // После 2 неудачных пингов считаем соединение потерянным
        if (consecutivePingFails >= maxMissedPings) {
          isConnected = false;
          sendPort.send(BackgroundConnectionService.MESSAGE_CONNECTION_LOST);
          updateNotification();
        }
      }

      // Отправляем сигнал проверки соединения
      sendPort.send(BackgroundConnectionService.MESSAGE_CHECK_CONNECTION);
    }
  });

  // Периодически обновляем состояние сервиса
  Timer.periodic(const Duration(seconds: 5), (_) {
    service.invoke('update', {
      'isRunning': true,
      'timestamp': DateTime.now().toIso8601String(),
      'deviceName': deviceName,
      'isConnected': isConnected,
    });
  });
}

/// Обробник для підтримки фонового режиму на iOS пристроях.
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}
