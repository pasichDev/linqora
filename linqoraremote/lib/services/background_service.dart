import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_storage/get_storage.dart';

/// Служба для підтримки з'єднання з хостом у фоновому режимі, коли додаток згорнутий.
/// Забезпечує постійний зв'язок з сервером та відображення сповіщень про статус з'єднання.
class BackgroundConnectionService {
  static const String _notificationChannelId = 'linqora_connection';
  static const int _notificationId = 888;
  static const String _portName = 'linqora_background_port';
  static const String _kEnableNotifications = 'enable_notifications';

  static ReceivePort? _receivePort;
  static FlutterBackgroundService? _service;

  /// Ініціалізує фоновий сервіс та налаштовує канали сповіщень.
  /// Викликається один раз при запуску додатка.
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();
    _service = service;

    // Инициализация для уведомлений
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _notificationChannelId,
      'Linqora Connection Service',
      description: 'Keeps the connection with Linqora host active',
      importance: Importance.high,
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
        initialNotificationTitle: 'Linqora Remote',
        initialNotificationContent: 'Поддержание соединения...',
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

  /// Запускає фоновий сервіс із вказаними параметрами підключення.
  /// Створює канал зв'язку між основним додатком та фоновою службою.
  static Future<bool> startService(
    String deviceName,
    String deviceAddress,
  ) async {
    if (_service == null) {
      await initializeService();
    }

    // Получаем текущие настройки уведомлений
    final storage = GetStorage('settings');
    final notificationsEnabled =
        storage.read<bool>(_kEnableNotifications) ?? false;

    _receivePort = ReceivePort();
    IsolateNameServer.registerPortWithName(_receivePort!.sendPort, _portName);

    _receivePort!.listen((message) {
      if (kDebugMode) {
        print('Сообщение от фонового сервиса: $message');
      }
    });

    await _service!.startService();

    // Передаем информацию о устройстве и настройках уведомлений
    _service!.invoke('updateDeviceInfo', {
      'deviceName': deviceName,
      'deviceAddress': deviceAddress,
      'notificationsEnabled': notificationsEnabled,
    });

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

  final sendPort = IsolateNameServer.lookupPortByName(
    'linqora_background_port',
  );
  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: 'Linqora Remote активен',
      content: 'Поддержание соединения...',
    );
  }

  service.on('updateDeviceInfo').listen((event) {
    if (event != null) {
      deviceName = event['deviceName'] ?? deviceName;
      deviceAddress = event['deviceAddress'] ?? deviceAddress;

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'Linqora Remote подключен',
          content: 'Подключено к $deviceName ($deviceAddress)',
        );
      }

      if (sendPort != null) {
        sendPort.send('deviceInfoUpdated');
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

  service.on('updateNotificationStatus').listen((event) {
    if (event != null) {
      bool notificationsEnabled = event['enabled'] ?? false;

      if (service is AndroidServiceInstance) {
        if (notificationsEnabled) {
          service.setForegroundNotificationInfo(
            title: 'Linqora Remote подключен',
            content: 'Подключено к $deviceName ($deviceAddress)',
          );
        } else {
          service.setForegroundNotificationInfo(
            title: 'Linqora Remote',
            content: 'Работает в фоне',
          );
        }
      }
    }
  });
  // Запускаем периодическую отправку ping
  Timer.periodic(const Duration(seconds: 30), (_) async {
    if (sendPort != null) {
      sendPort.send('ping');
    }
  });

  // Периодически проверяем состояние
  Timer.periodic(const Duration(seconds: 5), (_) async {
    service.invoke('update', {
      'isRunning': true,
      'timestamp': DateTime.now().toIso8601String(),
      'deviceName': deviceName,
    });
  });
}

/// Обробник для підтримки фонового режиму на iOS пристроях.
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}
