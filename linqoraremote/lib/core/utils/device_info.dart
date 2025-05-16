import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

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

Future<String> getDeviceId() async {
  if (Platform.isAndroid) {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    return androidInfo.id ?? 'unknown';
  } else if (Platform.isIOS) {
    final iosInfo = await DeviceInfoPlugin().iosInfo;
    return iosInfo.identifierForVendor ?? 'unknown';
  }
  return 'unknown';
}

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
