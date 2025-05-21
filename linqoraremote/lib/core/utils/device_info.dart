import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Retrieves the name of the device.
///
/// - **Behavior**:
///   - For Android devices, it returns the manufacturer and model (e.g., "Samsung Galaxy S21").
///   - For iOS devices, it returns the name and model (e.g., "iPhone 12").
///   - For other platforms, it returns "Unknown device".
///
/// - **Returns**: A `Future` that resolves to a `String` containing the device name.
Future<String> getDeviceName() async {
  final deviceInfoPlugin = DeviceInfoPlugin();

  if (Platform.isAndroid) {
    final androidInfo = await deviceInfoPlugin.androidInfo;
    return '${androidInfo.manufacturer} ${androidInfo.model}';
  } else if (Platform.isIOS) {
    final iosInfo = await deviceInfoPlugin.iosInfo;
    return '${iosInfo.name} ${iosInfo.model}';
  } else {
    return 'Unknown device';
  }
}

/// Retrieves the unique identifier of the device.
///
/// - **Behavior**:
///   - For Android devices, it returns the device ID.
///   - For iOS devices, it returns the `identifierForVendor` or "unknown" if unavailable.
///   - For other platforms, it returns "unknown".
///
/// - **Returns**: A `Future` that resolves to a `String` containing the device ID.
Future<String> getDeviceId() async {
  if (Platform.isAndroid) {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    return androidInfo.id;
  } else if (Platform.isIOS) {
    final iosInfo = await DeviceInfoPlugin().iosInfo;
    return iosInfo.identifierForVendor ?? 'unknown';
  }
  return 'unknown';
}

/// Retrieves the local IPv4 address of the device.
///
/// - **Behavior**:
///   - Scans the network interfaces to find the first non-loopback IPv4 address.
///   - If no address is found or an error occurs, it returns "0.0.0.0".
///   - Logs errors in debug mode.
///
/// - **Returns**: A `Future` that resolves to a `String` containing the local IP address.
Future<String> getLocalIpAddress() async {
  try {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );

    for (final interface in interfaces) {
      for (final addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4) {
          return addr.address;
        }
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error getting local IP: $e');
    }
  }
  return '0.0.0.0'; // Fallback
}

/// Retrieves the version of the application.
///
/// - **Behavior**:
///   - Uses the `PackageInfo` plugin to fetch the app version.
///   - The version is defined in the app's configuration (e.g., `pubspec.yaml` for Flutter apps).
///
/// - **Returns**: A `Future` that resolves to a `String` containing the app version.
Future<String> getAppVersion() async {
  final packageInfo = await PackageInfo.fromPlatform();
  return packageInfo.version;
}
