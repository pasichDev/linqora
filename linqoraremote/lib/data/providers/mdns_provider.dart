import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:multicast_dns/multicast_dns.dart';

import '../../core/utils/app_logger.dart';
import '../models/discovered_service.dart';

/// Status of mDNS discovery process
enum DiscoveryStatus { started, deviceFound, completed, empty, error }

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
  /// Returns true if successful, false otherwise
  Future<bool> _enableMulticast() async {
    if (!Platform.isAndroid) return true;

    const wifiMulticastChannel = MethodChannel('android.net.wifi.WifiManager');
    try {
      final result = await wifiMulticastChannel.invokeMethod(
        'acquireMulticastLock',
      );

      AppLogger.debug(
        'Multicast lock acquired: $result',
        module: "MDnsProvider",
      );

      return true;
    } catch (e) {
      AppLogger.release(
        'Failed to activate multicast: $e',
        module: "MDnsProvider",
      );
      onStatusChanged?.call(
        DiscoveryStatus.error,
        message: "Failed to activate multicast: $e",
      );
      return false;
    }
  }

  /// Stops the current discovery process and releases resources
  void _stopDiscovery() {
    try {
      _client?.stop();
      _client = null;
    } catch (e) {
      AppLogger.debug('Error stopping mDNS client: $e', module: "MDnsProvider");
    }
  }

  /// Cancels ongoing discovery operation
  void cancelDiscovery() {
    if (_discoveryTimer?.isActive ?? false) {
      _discoveryTimer!.cancel();
    }
    _stopDiscovery();

    AppLogger.debug('mDNS discovery canceled', module: "MDnsProvider");
  }

  /// Dispose resources
  void dispose() {
    cancelDiscovery();
  }

  Future<List<MdnsDevice>> discoverLinqoraDevices({
    bool useDirectSearch = true,
    bool useDnsSdSearch = false,
    bool avoidDuplicates = true,
  }) async {
    final devices = <MdnsDevice>[];
    final startTime = DateTime.now();

    try {
      if (!await _initializeDiscovery()) {
        return [];
      }
      AppLogger.debug(
        "Start the search with a timeout of $discoveryTimeout seconds",
        module: "MDnsProvider",
      );
      _cancelDiscoveryTimer();
      _discoveryTimer = Timer(Duration(seconds: discoveryTimeout), () {
        _stopDiscovery();
      });

      /// Start search
      if (useDirectSearch && useDnsSdSearch && !avoidDuplicates) {
        await Future.wait([
          _performDirectSearch(devices),
          _performDnsSdSearch(devices),
        ]);
      } else {
        /// Start direct search
        if (useDirectSearch) {
          await _performDirectSearch(devices);
        }

        if (devices.isEmpty || useDnsSdSearch) {
          await _performDnsSdSearch(devices);
        }
      }

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      AppLogger.release(
        'Device search completed in $duration ms, found: ${devices.length}',
        module: "MDnsProvider",
      );
      return _finalizeDiscovery(devices);
    } catch (e) {
      AppLogger.release(
        'Error when searching for devices: ${devices.length}',
        module: "MDnsProvider",
      );
      _stopDiscovery();
      return [];
    }
  }

  /// Initializes mDNS discovery process
  Future<bool> _initializeDiscovery() async {
    onStatusChanged?.call(DiscoveryStatus.started);

    if (!await _enableMulticast()) {
      return false;
    }

    _client = MDnsClient();
    await _client!.start();
    AppLogger.release(
      'Starting mDNS discovery for Linqora devices',
      module: "MDnsProvider",
    );
    _startDiscoveryTimer();
    return true;
  }

  /// Performs direct search for Linqora services
  Future<void> _performDirectSearch(List<MdnsDevice> devices) async {
    try {
      await for (final ptr in _client!.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer('_linqora.local'),
      )) {
        AppLogger.debug(
          'Found Linqora service: ${ptr.domainName}',
          module: "MDnsProvider",
        );
        await _processLinqoraInstance(ptr.domainName, devices);
      }
    } catch (e) {
      AppLogger.release(
        'Error in direct search: ${e.toString()}',
        module: "MDnsProvider",
      );
    }
  }

  /// Performs DNS-SD search for Linqora services
  Future<void> _performDnsSdSearch(List<MdnsDevice> devices) async {
    try {
      await for (final serviceType in _client!.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer('_services._dns-sd._udp.local'),
      )) {
        AppLogger.release(
          'Found service type via DNS-SD: ${serviceType.domainName}',
          module: "MDnsProvider",
        );
        if (_isLinqoraServiceType(serviceType.domainName)) {
          await for (final instance in _client!.lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer(serviceType.domainName),
          )) {
            await _processLinqoraInstance(instance.domainName, devices);
          }
        }
      }
    } catch (e) {
      AppLogger.release(
        'Error when searching via DNS-SD: ${e.toString()}',
        module: "MDnsProvider",
      );
    }
  }

  /// Finalizes the discovery process
  List<MdnsDevice> _finalizeDiscovery(List<MdnsDevice> devices) {
    _cancelDiscoveryTimer();
    _stopDiscovery();

    if (devices.isEmpty) {
      onStatusChanged?.call(DiscoveryStatus.empty);
    } else {
      onStatusChanged?.call(DiscoveryStatus.completed);
    }

    return devices;
  }

  void _startDiscoveryTimer() {
    _cancelDiscoveryTimer();
    _discoveryTimer = Timer(Duration(seconds: discoveryTimeout), () {
      _stopDiscovery();
      onStatusChanged?.call(DiscoveryStatus.empty);
    });
  }

  void _cancelDiscoveryTimer() {
    if (_discoveryTimer?.isActive ?? false) {
      _discoveryTimer!.cancel();
      _discoveryTimer = null;
    }
  }

  Future<void> _processLinqoraInstance(
    String serviceName,
    List<MdnsDevice> devices,
  ) async {
    try {
      final srvRecords =
          await _client!
              .lookup<SrvResourceRecord>(
                ResourceRecordQuery.service(serviceName),
              )
              .toList();

      if (srvRecords.isEmpty) {
        return;
      }

      final srv = srvRecords.first;
      final txtData = await _parseTxtRecords(serviceName);
      final ipAddresses =
          await _client!
              .lookup<IPAddressResourceRecord>(
                ResourceRecordQuery.addressIPv4(srv.target),
              )
              .toList();

      if (ipAddresses.isEmpty) {
        AppLogger.debug(
          'No IP addresses found for ${srv.target}',
          module: "MDnsProvider",
        );
        return;
      }

      /// Create a device with the best IP address
      String serviceParts = serviceName.split('._')[0];
      if (serviceParts.startsWith('_')) {
        serviceParts = serviceParts.substring(1);
      }

      /// Select the best IP address
      final bestIp = _selectBestIpAddress(ipAddresses);
      final device = MdnsDevice(
        name:
            txtData['hostname']?.isNotEmpty == true
                ? txtData['hostname']!
                : serviceParts,
        address: bestIp.address.address,
        port: srv.port.toString(),
        supportsTLS: txtData['supportsTLS'] == 'true',
      );

      if (!_deviceExists(devices, device)) {
        devices.add(device);
        onStatusChanged?.call(DiscoveryStatus.deviceFound);
        AppLogger.debug(
          'Device added: ${device.name} (${device.address}:${device.port})',
          module: "MDnsProvider",
        );
      } else {
        AppLogger.debug(
          'Device already exists: ${device.name} (${device.address}:${device.port})',
          module: "MDnsProvider",
        );
      }
    } catch (e) {
      AppLogger.release(
        'Error processing service $serviceName: ${e.toString()}',
        module: "MDnsProvider",
      );
    }
  }

  /// Selects the best IP address from a list of addresses
  IPAddressResourceRecord _selectBestIpAddress(
    List<IPAddressResourceRecord> addresses,
  ) {
    /// Filter out unwanted addresses
    final filteredAddresses =
        addresses.where((record) {
          final ip = record.address.address;
          return !ip.startsWith('172.17.') && // Docker
              !ip.startsWith('127.') && // Localhost
              !ip.startsWith('10.') && // Private
              !ip.startsWith('169.254.'); // Link-local
        }).toList();

    return filteredAddresses.isNotEmpty
        ? filteredAddresses.first
        : addresses.first;
  }

  /// Parses TXT records for a given service name
  Future<Map<String, String>> _parseTxtRecords(String serviceName) async {
    final Map<String, String> result = {'supportsTLS': 'false', 'hostname': ''};

    try {
      final txtRecords =
          await _client!
              .lookup<TxtResourceRecord>(ResourceRecordQuery.text(serviceName))
              .toList();

      for (final txt in txtRecords) {
        final entries = _parseTxtString(txt.text);

        if (entries.containsKey('tls') &&
            entries['tls']!.toLowerCase() == 'true') {
          result['supportsTLS'] = 'true';
        }

        final fieldsToMap = ['hostname'];
        for (final field in fieldsToMap) {
          if (entries.containsKey(field) && entries[field]!.isNotEmpty) {
            result[field] = entries[field]!;
          }
        }
      }
    } catch (e) {
      AppLogger.release(
        'Error when processing TXT records ${e.toString()}',
        module: "MDnsProvider",
      );
    }

    return result;
  }

  /// Parses a TXT string into a map of key-value pairs
  Map<String, String> _parseTxtString(String txtString) {
    final result = <String, String>{};

    final entries = txtString.split(RegExp(r'[;\s]'));

    for (final entry in entries) {
      final trimmed = entry.trim();
      if (trimmed.isEmpty) continue;
      final keyValueMatch = RegExp(r'^([^=:]+)[=:](.*)$').firstMatch(trimmed);
      if (keyValueMatch != null) {
        final key = keyValueMatch.group(1)?.toLowerCase();
        final value = keyValueMatch.group(2);

        if (key != null && value != null && key.isNotEmpty) {
          result[key] = value;
        }
      }
    }

    return result;
  }

  /// Checks if the service type is Linqora
  bool _isLinqoraServiceType(String serviceType) {
    return serviceType.contains('_linqora');
  }

  /// Checks if a device already exists in the list
  bool _deviceExists(List<MdnsDevice> devices, MdnsDevice device) {
    return devices.any(
      (d) => d.address == device.address && d.port == device.port,
    );
  }
}
