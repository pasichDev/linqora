import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:multicast_dns/multicast_dns.dart';

import '../models/discovered_service.dart';

/// Status of mDNS discovery process
enum DiscoveryStatus { started, deviceFound, completed, empty, error, timeout }

class MDnsProvider {
  /// Callback for discovery status changes
  Function(DiscoveryStatus status, {String? message})? onStatusChanged;

  /// Default timeout for discovery operations in seconds
  final int discoveryTimeout;

  /// MDns client instance
  MDnsClient? _client;

  /// Timer for discovery timeout
  Timer? _discoveryTimer;

  MDnsProvider({this.discoveryTimeout = 10});

  /// Enables multicast capability on Android devices
  ///
  /// Returns true if successful, false otherwise
  Future<bool> enableMulticast() async {
    // Only applicable to Android
    if (!Platform.isAndroid) return true;

    const wifiMulticastChannel = MethodChannel('android.net.wifi.WifiManager');
    try {
      final result = await wifiMulticastChannel.invokeMethod(
        'acquireMulticastLock',
      );

      if (kDebugMode) {
        print('Multicast lock acquired: $result');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print("Failed to activate multicast: $e");
      }
      onStatusChanged?.call(
        DiscoveryStatus.error,
        message: "Failed to activate multicast: $e",
      );
      return false;
    }
  }

  /// Discovers devices on the network with the specified device code
  ///
  /// Returns a list of discovered services or empty list if none found
  Future<List<DiscoveredService>> discoverDevices(String deviceCode) async {
    List<DiscoveredService> devices = [];
    Completer<List<DiscoveredService>> completer = Completer();

    try {
      // Notify that discovery has started
      onStatusChanged?.call(DiscoveryStatus.started);

      // Enable multicast for Android devices
      final multicastEnabled = await enableMulticast();
      if (!multicastEnabled) {
        completer.complete([]);
        return [];
      }

      _client = MDnsClient();
      await _client!.start();

      if (kDebugMode) {
        print('Starting mDNS discovery for: $deviceCode._tcp.local');
      }

      // Set timeout for discovery
      _discoveryTimer = Timer(Duration(seconds: discoveryTimeout), () {
        if (!completer.isCompleted) {
          onStatusChanged?.call(
            DiscoveryStatus.timeout,
            message: 'Пошук пристроїв перервано через таймаут',
          );
          _stopDiscovery();
          completer.complete(devices);
        }
      });

      // Listen for PTR records
      try {
        await for (final PtrResourceRecord ptr in _client!
            .lookup<PtrResourceRecord>(
              ResourceRecordQuery.serverPointer('_$deviceCode._tcp.local'),
            )) {
          if (kDebugMode) {
            print('Found PTR: ${ptr.domainName}');
          }

          onStatusChanged?.call(DiscoveryStatus.deviceFound);

          // Look up SRV records for the PTR
          await for (final SrvResourceRecord srv in _client!
              .lookup<SrvResourceRecord>(
                ResourceRecordQuery.service(ptr.domainName),
              )) {
            // Look up IP addresses for the SRV target
            await for (final IPAddressResourceRecord ip in _client!
                .lookup<IPAddressResourceRecord>(
                  ResourceRecordQuery.addressIPv4(srv.target),
                )) {
              final device = DiscoveredService(
                name: ptr.domainName,
                address: ip.address.address,
                port: srv.port.toString(),
              );

              devices.add(device);

              if (kDebugMode) {
                print('Found device: ${ip.address.address}:${srv.port}');
              }
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error during mDNS lookup: $e');
        }
        onStatusChanged?.call(
          DiscoveryStatus.error,
          message: 'Error during mDNS lookup: $e',
        );
      }

      // Cancel the timer if discovery completes before timeout
      if (_discoveryTimer?.isActive ?? false) {
        _discoveryTimer!.cancel();
      }

      _stopDiscovery();

      if (devices.isEmpty) {
        onStatusChanged?.call(
          DiscoveryStatus.empty,
          message: 'Пристроїв не знайдено',
        );
      } else {
        onStatusChanged?.call(
          DiscoveryStatus.completed,
          message: 'Знайдено ${devices.length} пристроїв',
        );
      }

      if (!completer.isCompleted) {
        completer.complete(devices);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Critical error during discovery: $e');
      }
      onStatusChanged?.call(
        DiscoveryStatus.error,
        message: 'Критична помилка під час пошуку: $e',
      );

      _stopDiscovery();

      if (!completer.isCompleted) {
        completer.complete([]);
      }
    }

    return completer.future;
  }

  /// Stops the current discovery process and releases resources
  void _stopDiscovery() {
    try {
      _client?.stop();
      _client = null;
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping mDNS client: $e');
      }
    }
  }

  /// Cancels ongoing discovery operation
  void cancelDiscovery() {
    if (_discoveryTimer?.isActive ?? false) {
      _discoveryTimer!.cancel();
    }
    _stopDiscovery();

    if (kDebugMode) {
      print('mDNS discovery canceled');
    }
  }

  /// Dispose resources
  void dispose() {
    cancelDiscovery();
  }
}
