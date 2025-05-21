import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:linqoraremote/core/constants/settings.dart';
import 'package:linqoraremote/core/utils/error_handler.dart';
import 'package:linqoraremote/services/permissions_service.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/utils/app_logger.dart';
import '../../core/utils/device_info.dart';

class SettingsController extends GetxController {
  final _storage = GetStorage(SettingsConst.kSettings);

  final Rx<ThemeMode> themeMode = ThemeMode.system.obs;
  final RxBool enableNotifications = false.obs;
  final RxBool enableAutoConnect = false.obs;
  final RxBool notificationPermissionGranted = false.obs;
  final RxString appVersion = ''.obs;

  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void onInit() {
    super.onInit();

    /// Load the settings from storage
    loadSettings();

    /// Initialize the notifications plugin
    checkNotificationPermission();

    /// Get app version
    _loadAppVersion();
  }

  @override
  void onClose() {
    themeMode.close();
    enableNotifications.close();
    enableAutoConnect.close();
    notificationPermissionGranted.close();
    appVersion.close();
    notificationsPlugin.pendingNotificationRequests().then((notifications) {
      for (final notification in notifications) {
        notificationsPlugin.cancel(notification.id);
      }
    });

    _storage.save();
    super.onClose();
  }

  Future<void> _loadAppVersion() async {
    final mAppVersion = await getAppVersion();
    appVersion.value = mAppVersion;
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

      Get.changeThemeMode(themeMode.value);
    } catch (e) {
      AppLogger.release(
        'Error loading settings: $e',
        module: "SettingsController",
      );
    }
  }

  /// Check notification permission status
  Future<void> checkNotificationPermission() async {
    try {
      final status = await PermissionsService.checkNotificationPermission();
      notificationPermissionGranted.value = status;

      /// Else if the permission is not granted and notifications are enabled,
      if (!status && enableNotifications.value) {
        enableNotifications.value = false;
        await _storage.write(SettingsConst.kEnableNotifications, false);
      }
    } catch (e) {
      showErrorSnackbar('Error check permission', e.toString());
      AppLogger.release(
        'Error check permission: $e',
        module: "SettingsController",
      );
    }
  }

  /// Request notification permission
  Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    notificationPermissionGranted.value = status.isGranted;
    return status.isGranted;
  }

  /// Request notification permission and check if it is granted
  Future<void> toggleNotifications(bool value) async {
    try {
      if (value && !notificationPermissionGranted.value) {
        final granted =
            await PermissionsService.requestNotificationPermission();
        if (!granted) {
          showErrorSnackbar(
            'empty_permission'.tr,
            'empty_permission_description'.tr,
          );
          return;
        }
        notificationPermissionGranted.value = granted;
      }

      /// If the permission is not granted and notifications are enabled,
      if (!value || notificationPermissionGranted.value) {
        enableNotifications.value = value;
        await _storage.write(SettingsConst.kEnableNotifications, value);
      }
    } catch (e) {
      AppLogger.release(
        'Error when switching notifications: $e',
        module: "SettingsController",
      );
      enableNotifications.value = value;
      await _storage.write(SettingsConst.kEnableNotifications, value);
    }
  }

  /// Save the theme mode to storage and change the app theme
  Future<void> saveThemeMode(ThemeMode mode) async {
    try {
      themeMode.value = mode;
      await _storage.write(SettingsConst.kThemeMode, _getThemeModeString(mode));
      Get.changeThemeMode(mode);
    } catch (e) {
      AppLogger.release('Error save theme: $e', module: "SettingsController");
    }
  }

  /// Save the auto connect setting to storage
  Future<void> toggleAutoConnect(bool value) async {
    enableAutoConnect.value = value;
    await _storage.write(SettingsConst.kEnableAutoConnect, value);
  }

  /// Get the theme mode from string
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

  /// Get the theme mode as string
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
