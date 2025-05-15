import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionsService {
  /// Проверяет наличие разрешения на уведомления
  static Future<bool> checkNotificationPermission() async {
    try {
      final status = await Permission.notification.status;
      return status.isGranted;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking notification permission: $e');
      }
      return true;
    }
  }

  /// Запрашивает разрешение на уведомления
  static Future<bool> requestNotificationPermission() async {
    try {
      final status = await Permission.notification.request();
      return status.isGranted;
    } catch (e) {
      if (kDebugMode) {
        print('Error requesting notification permission: $e');
      }
      return true;
    }
  }

  /// Открывает настройки приложения
  static Future<void> openAppSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      if (kDebugMode) {
        print('Error opening app settings: $e');
      }
    }
  }
}
