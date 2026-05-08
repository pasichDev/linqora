import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionsService {
  static bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  /// Checks if the app has permission to access notifications
  static Future<bool> checkNotificationPermission() async {
    if (_isDesktop) return true;
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

  /// Requests permission to access notifications
  static Future<bool> requestNotificationPermission() async {
    if (_isDesktop) return true;
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

  /// Checks if the app has permission to access location
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
