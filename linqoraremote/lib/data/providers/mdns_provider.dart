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
  /// Returns true if successful, false otherwise
  Future<bool> _enableMulticast() async {
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

  Future<List<DiscoveredService>> discoverLinqoraDevices({
    bool useDirectSearch = true,
    bool useDnsSdSearch = false,
    bool avoidDuplicates = true,
  }) async {
    final devices = <DiscoveredService>[];
    final startTime = DateTime.now();

    try {
      if (!await _initializeDiscovery()) {
        return [];
      }

      // Устанавливаем таймаут
      _log('Начинаем поиск с таймаутом $discoveryTimeout секунд');
      _cancelDiscoveryTimer();
      _discoveryTimer = Timer(Duration(seconds: discoveryTimeout), () {
        _log('Таймаут поиска ($discoveryTimeout сек)');
        _stopDiscovery();
      });

      // Запускаем поиск
      if (useDirectSearch && useDnsSdSearch && !avoidDuplicates) {
        await Future.wait([
          _performDirectSearch(devices),
          _performDnsSdSearch(devices),
        ]);
      } else {
        // Иначе запускаем последовательно, чтобы избежать дублирования
        if (useDirectSearch) {
          await _performDirectSearch(devices);
        }

        if (devices.isEmpty || useDnsSdSearch) {
          await _performDnsSdSearch(devices);
        }
      }

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      _log(
        'Поиск устройств завершен за $duration мс, найдено: ${devices.length}',
      );

      return _finalizeDiscovery(devices);
    } catch (e) {
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      _logError('Ошибка при поиске устройств ($duration мс)', e);
      _stopDiscovery();
      return [];
    }
  }

  // Инициализация поиска
  Future<bool> _initializeDiscovery() async {
    onStatusChanged?.call(DiscoveryStatus.started);

    if (!await _enableMulticast()) {
      return false;
    }

    _client = MDnsClient();
    await _client!.start();
    _log('Начинаем mDNS-обнаружение для Linqora-устройств');

    // Запускаем таймер для ограничения времени поиска
    _startDiscoveryTimer();

    return true;
  }

  // Прямой поиск по типу сервиса
  Future<void> _performDirectSearch(List<DiscoveredService> devices) async {
    try {
      _log('Ищем Linqora сервисы с типом "_linqora._tcp.local"');

      await for (final ptr in _client!.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer('_linqora._tcp.local'),
      )) {
        _log('Найден Linqora сервис: ${ptr.domainName}');
        await _processLinqoraInstance(ptr.domainName, devices);
      }
    } catch (e) {
      _logError('Ошибка при прямом поиске', e);
    }
  }

  // Поиск через DNS-SD
  Future<void> _performDnsSdSearch(List<DiscoveredService> devices) async {
    try {
      _log('Пробуем поиск через DNS-SD...');

      await for (final serviceType in _client!.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer('_services._dns-sd._udp.local'),
      )) {
        _log('Найден тип сервиса через DNS-SD: ${serviceType.domainName}');

        if (_isLinqoraServiceType(serviceType.domainName)) {
          await for (final instance in _client!.lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer(serviceType.domainName),
          )) {
            _log(
              'Найден экземпляр ${serviceType.domainName}: ${instance.domainName}',
            );
            await _processLinqoraInstance(instance.domainName, devices);
          }
        }
      }
    } catch (e) {
      _logError('Ошибка при поиске через DNS-SD', e);
    }
  }

  // Завершение поиска и обработка результатов
  List<DiscoveredService> _finalizeDiscovery(List<DiscoveredService> devices) {
    _cancelDiscoveryTimer();
    _stopDiscovery();

    if (devices.isEmpty) {
      onStatusChanged?.call(
        DiscoveryStatus.empty,
        message: 'Устройства не найдены',
      );
    } else {
      onStatusChanged?.call(
        DiscoveryStatus.completed,
        message: 'Найдено ${devices.length} устройств',
      );
    }

    return devices;
  }

  void _startDiscoveryTimer() {
    _cancelDiscoveryTimer();
    _discoveryTimer = Timer(Duration(seconds: discoveryTimeout), () {
      _log('Timeout: завершаем поиск');
      _stopDiscovery();
      onStatusChanged?.call(
        DiscoveryStatus.timeout,
        message: 'Поиск завершен по таймауту',
      );
    });
  }

  void _log(String message) {
    if (kDebugMode) {
      print('[MDnsProvider] $message');
    }
  }

  void _logError(String context, dynamic error) {
    if (kDebugMode) {
      print('[MDnsProvider] $context: $error');
    }
  }

  void _cancelDiscoveryTimer() {
    if (_discoveryTimer?.isActive ?? false) {
      _discoveryTimer!.cancel();
      _discoveryTimer = null;
    }
  }

  Future<void> _processLinqoraInstance(
    String serviceName,
    List<DiscoveredService> devices,
  ) async {
    try {
      _log('Обработка сервиса: $serviceName');

      // Получаем все SRV записи сразу
      final srvRecords =
          await _client!
              .lookup<SrvResourceRecord>(
                ResourceRecordQuery.service(serviceName),
              )
              .toList();

      if (srvRecords.isEmpty) {
        _log('Сервис $serviceName не имеет SRV записей');
        return;
      }

      // Обрабатываем первую SRV запись
      final srv = srvRecords.first;
      _log('SRV запись: ${srv.target}:${srv.port}');

      // Централизованно получаем и обрабатываем TXT записи
      final txtData = await _parseTxtRecords(serviceName);

      // Получаем все IP адреса хоста
      final ipAddresses =
          await _client!
              .lookup<IPAddressResourceRecord>(
                ResourceRecordQuery.addressIPv4(srv.target),
              )
              .toList();

      if (ipAddresses.isEmpty) {
        _log('Не найдено IP адресов для ${srv.target}');
        return;
      }

      // Создаем понятное имя сервиса
      String serviceParts = serviceName.split('._')[0];
      if (serviceParts.startsWith('_')) {
        serviceParts = serviceParts.substring(1);
      }

      // Выбираем основной IP (предпочитаем не локальные и не Docker)
      final bestIp = _selectBestIpAddress(ipAddresses);
      _log('Выбран основной IP: ${bestIp.address.address}');

      // Создаем устройство с лучшим IP
      final device = DiscoveredService(
        id: serviceParts,
        name:
            txtData['hostname']?.isNotEmpty == true
                ? txtData['hostname']!
                : serviceParts,
        address: bestIp.address.address,
        port: srv.port.toString(),
        supportsTLS: txtData['supportsTLS'] == 'true',
        hostname: txtData['hostname'] ?? '',
        osInfo: txtData['osInfo'] ?? '',
      );

      if (!_deviceExists(devices, device)) {
        devices.add(device);
        onStatusChanged?.call(DiscoveryStatus.deviceFound);
        _log(
          'Добавлено устройство: ${device.name} (${device.address}:${device.port})',
        );
      } else {
        _log('Устройство ${device.name} уже существует в списке');
      }
    } catch (e) {
      _logError('Ошибка при обработке сервиса $serviceName', e);
    }
  }

  // Метод для выбора лучшего IP адреса
  IPAddressResourceRecord _selectBestIpAddress(
    List<IPAddressResourceRecord> addresses,
  ) {
    // Фильтруем Docker и локальные адреса
    final filteredAddresses =
        addresses.where((record) {
          final ip = record.address.address;
          return !ip.startsWith('172.17.') && // Docker сеть
              !ip.startsWith('127.') && // Localhost
              !ip.startsWith('10.') && // Частные адреса
              !ip.startsWith('169.254.'); // Link-local
        }).toList();

    // Если есть подходящие адреса, берем первый, иначе возвращаем первый из всех
    return filteredAddresses.isNotEmpty
        ? filteredAddresses.first
        : addresses.first;
  }

  // Полностью переработанный метод обработки TXT записей
  Future<Map<String, String>> _parseTxtRecords(String serviceName) async {
    final Map<String, String> result = {
      'supportsTLS': 'false',
      'hostname': '',
      'osInfo': '',
      'username': '',
      'ip': '',
    };

    try {
      final txtRecords =
          await _client!
              .lookup<TxtResourceRecord>(ResourceRecordQuery.text(serviceName))
              .toList();

      for (final txt in txtRecords) {
        _log('TXT запись: ${txt.text}');

        // Единый подход к обработке TXT записей
        final entries = _parseTxtString(txt.text);

        // Обновляем результат из полученных данных
        if (entries.containsKey('tls') &&
            entries['tls']!.toLowerCase() == 'true') {
          result['supportsTLS'] = 'true';
        }

        // Копируем важные поля
        final fieldsToMap = ['hostname', 'os', 'username', 'ip'];
        for (final field in fieldsToMap) {
          if (entries.containsKey(field) && entries[field]!.isNotEmpty) {
            if (field == 'os') {
              result['osInfo'] = entries[field]!;
            } else {
              result[field] = entries[field]!;
            }
          }
        }
      }
    } catch (e) {
      _logError('Ошибка при обработке TXT записей', e);
    }

    return result;
  }

  // Новый вспомогательный метод для разбора TXT строки
  Map<String, String> _parseTxtString(String txtString) {
    final result = <String, String>{};

    // Обработка разных форматов TXT записей
    final entries = txtString.split(RegExp(r'[;\s]'));

    for (final entry in entries) {
      final trimmed = entry.trim();
      if (trimmed.isEmpty) continue;

      // Проверка на формат key=value и key:value
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

  // Проверяет, что тип сервиса может быть Linqora сервисом
  bool _isLinqoraServiceType(String serviceType) {
    return serviceType.contains('_linqora');
  }

  // Проверяет, существует ли устройство в списке
  bool _deviceExists(
    List<DiscoveredService> devices,
    DiscoveredService device,
  ) {
    return devices.any(
      (d) => d.address == device.address && d.port == device.port,
    );
  }
}
