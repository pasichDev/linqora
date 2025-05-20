import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:linqoraremote/core/constants/settings.dart';
import 'package:linqoraremote/data/models/discovered_service.dart';
import 'package:linqoraremote/services/permissions_service.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsController extends GetxController {
  final _storage = GetStorage(SettingsConst.kSettings);

  final Rx<ThemeMode> themeMode = ThemeMode.system.obs;
  final RxBool enableNotifications = false.obs;
  final RxBool enableAutoConnect = false.obs;
  final RxBool notificationPermissionGranted = false.obs;
  final RxBool showSponsorHome = true.obs;

  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

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
    enableNotifications.close();
    enableAutoConnect.close();
    notificationPermissionGranted.close();
    showSponsorHome.close();

    // Clean up notifications plugin resources
    notificationsPlugin.pendingNotificationRequests().then((notifications) {
      for (final notification in notifications) {
        notificationsPlugin.cancel(notification.id);
      }
    });

    _storage.save();
    super.onClose();
  }

  void loadSettings() {
    try {
      final themeModeValue =
          _storage.read<String>(SettingsConst.kThemeMode) ?? 'system';
      themeMode.value = _getThemeMode(themeModeValue);

      enableNotifications.value =
          _storage.read<bool>(SettingsConst.kEnableNotifications) ?? false;
      enableAutoConnect.value =
          _storage.read<bool>(SettingsConst.kEnableAutoConnect) ?? false;

      showSponsorHome.value =
          _storage.read<bool>(SettingsConst.kShowSponsorHome) ?? true;
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
        await _storage.write(SettingsConst.kEnableNotifications, false);
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
        await _storage.write(SettingsConst.kEnableNotifications, value);
      }
    } catch (e) {
      printError(info: 'Ошибка при переключении уведомлений: $e');
      enableNotifications.value = value;
      await _storage.write(SettingsConst.kEnableNotifications, value);
    }
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    try {
      themeMode.value = mode;
      await _storage.write(SettingsConst.kThemeMode, _getThemeModeString(mode));
      Get.changeThemeMode(mode);
    } catch (e) {
      printError(info: 'Ошибка сохранения темы: $e');
    }
  }

  Future<void> toggleAutoConnect(bool value) async {
    enableAutoConnect.value = value;
    await _storage.write(SettingsConst.kEnableAutoConnect, value);
  }

  Future<void> toggleShowSponsorHome(bool value) async {
    showSponsorHome.value = value;
    await _storage.write(SettingsConst.kShowSponsorHome, value);
  }

  Future<void> saveLastConnect(MdnsDevice value) async {
    await _storage.write(SettingsConst.kLastConnect, value.toJson());
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
