import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:linqoraremote/presentation/controllers/device_home_controller.dart';
import 'package:linqoraremote/services/permissions_service.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsController extends GetxController {
  static const _kThemeMode = 'theme_mode';
  static const _kShowMetrics = 'show_metrics';
  static const _kEnableNotifications = 'enable_notifications';
  static const _kEnableAutoConnect = 'enable_auto_connect';
  static const _kKeepAliveInterval = 'keep_alive_interval';
  static const _kEnableBackgroundService = 'enable_background_service';
  static const _kActivePingInterval = 'active_ping_interval';
  static const _kBackgroundPingInterval = 'background_ping_interval';
  static const _kPingTimeout = 'ping_timeout';
  static const _kMaxMissedPings = 'max_missed_pings';

  final _storage = GetStorage('settings');

  final Rx<ThemeMode> themeMode = ThemeMode.system.obs;
  final RxBool showMetrics = true.obs;
  final RxBool enableNotifications = false.obs;
  final RxBool enableAutoConnect = false.obs;
  final RxInt keepAliveInterval = 10.obs;
  final RxBool enableBackgroundService = false.obs;

  final RxBool notificationPermissionGranted = false.obs;

  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Добавьте флаг для отслеживания фонового режима
  final RxBool backgroundMode = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadSettings();
    checkNotificationPermission();
  }

  @override
  void onClose() {
    // Dispose RxVariables
    themeMode.close();
    showMetrics.close();
    enableNotifications.close();
    enableAutoConnect.close();
    keepAliveInterval.close();
    enableBackgroundService.close();
    notificationPermissionGranted.close();
    backgroundMode.close();

    // Clean up notifications plugin resources
    notificationsPlugin.pendingNotificationRequests().then((notifications) {
      for (final notification in notifications) {
        notificationsPlugin.cancel(notification.id);
      }
    });

    // Close storage if needed
    _storage.save();

    super.onClose();

    if (kDebugMode) {
      print('SettingsController resources released successfully');
    }
  }

  void loadSettings() {
    try {
      final themeModeValue = _storage.read<String>(_kThemeMode) ?? 'system';
      themeMode.value = _getThemeMode(themeModeValue);

      showMetrics.value = _storage.read<bool>(_kShowMetrics) ?? true;
      enableNotifications.value =
          _storage.read<bool>(_kEnableNotifications) ?? false;
      enableAutoConnect.value =
          _storage.read<bool>(_kEnableAutoConnect) ?? false;
      keepAliveInterval.value = _storage.read<int>(_kKeepAliveInterval) ?? 10;
      enableBackgroundService.value =
          _storage.read<bool>(_kEnableBackgroundService) ?? false;

      Get.changeThemeMode(themeMode.value);
    } catch (e) {
      printError(info: 'Ошибка загрузки настроек: $e');
    }
  }

  // Проверка разрешения уведомлений при запуске
  Future<void> checkNotificationPermission() async {
    try {
      final status = await PermissionsService.checkNotificationPermission();
      notificationPermissionGranted.value = status;

      // Если разрешение не выдано, но настройка включена - отключаем настройку
      if (!status && enableNotifications.value) {
        enableNotifications.value = false;
        await _storage.write(_kEnableNotifications, false);
      }
    } catch (e) {
      // Обрабатываем ошибку - не блокируем функционал
      notificationPermissionGranted.value = true;
      printError(info: 'Ошибка проверки разрешений: $e');
    }
  }

  // Запрос разрешения на уведомления
  Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    notificationPermissionGranted.value = status.isGranted;
    return status.isGranted;
  }

  // Обновленный метод переключения уведомлений с запросом разрешений
  Future<void> toggleNotifications(bool value) async {
    try {
      if (value && !notificationPermissionGranted.value) {
        final granted =
            await PermissionsService.requestNotificationPermission();
        if (!granted) {
          Get.snackbar(
            'Отсутствует разрешение',
            'Чтобы получать уведомления, предоставьте разрешение в настройках устройства',
            snackPosition: SnackPosition.BOTTOM,
            duration: Duration(seconds: 5),
            mainButton: TextButton(
              child: Text('Настройки', style: TextStyle(color: Colors.white)),
              onPressed: () => PermissionsService.openAppSettings(),
            ),
            backgroundColor: Colors.orange.shade800,
            colorText: Colors.white,
          );
          return;
        }
        notificationPermissionGranted.value = granted;
      }

      // Установка значения только если разрешения получены или отключаем уведомления
      if (!value || notificationPermissionGranted.value) {
        enableNotifications.value = value;
        await _storage.write(_kEnableNotifications, value);
      }
    } catch (e) {
      printError(info: 'Ошибка при переключении уведомлений: $e');
      enableNotifications.value = value;
      await _storage.write(_kEnableNotifications, value);
    }
  }

  Future<void> toggleBackgroundService(bool value) async {
    enableBackgroundService.value = value;
    await _storage.write(_kEnableBackgroundService, value);

    if (!value && Get.isRegistered<DeviceHomeController>()) {
      final controller = Get.find<DeviceHomeController>();
      if (controller.isBackgroundServiceRunning.value) {
        controller.stopBackgroundService();
      }
    }
  }


  Future<void> saveThemeMode(ThemeMode mode) async {
    try {
      themeMode.value = mode;
      await _storage.write(_kThemeMode, _getThemeModeString(mode));
      Get.changeThemeMode(mode);
    } catch (e) {
      printError(info: 'Ошибка сохранения темы: $e');
    }
  }

  Future<void> toggleShowMetrics(bool value) async {
    showMetrics.value = value;
    await _storage.write(_kShowMetrics, value);
  }

  Future<void> toggleAutoConnect(bool value) async {
    enableAutoConnect.value = value;
    await _storage.write(_kEnableAutoConnect, value);
  }

  Future<void> setKeepAliveInterval(int value) async {
    keepAliveInterval.value = value;
    await _storage.write(_kKeepAliveInterval, value);
  }





  // Метод для установки режима приложения
  void setBackgroundMode(bool isBackground) {
    backgroundMode.value = isBackground;
  }



  ThemeMode _getThemeMode(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _getThemeModeString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      default:
        return 'system';
    }
  }
}
