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
      final multicastEnabled = await _enableMulticast();
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

          await for (final SrvResourceRecord srv in _client!
              .lookup<SrvResourceRecord>(
                ResourceRecordQuery.service(ptr.domainName),
              )) {
            bool supportsTLS = false;

            await for (final TxtResourceRecord txt in _client!
                .lookup<TxtResourceRecord>(
                  ResourceRecordQuery.text(ptr.domainName),
                )) {
              // Правильная проверка текстовой записи
              final txtString = txt.text.toString();
              if (txtString.contains('tls=true')) {
                supportsTLS = true;
              }
            }

            // Теперь обрабатываем IP-адреса и создаем устройства
            await for (final IPAddressResourceRecord ip in _client!
                .lookup<IPAddressResourceRecord>(
                  ResourceRecordQuery.addressIPv4(srv.target),
                )) {
              final device = DiscoveredService(
                name: ptr.domainName,
                address: ip.address.address,
                port: srv.port.toString(),
                supportsTLS: supportsTLS,
                id: "o",
              );

              devices.add(device);

              if (kDebugMode) {
                print(
                  'Found device: ${ip.address.address}:${srv.port} (TLS support: $supportsTLS)',
                );
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

  Future<List<DiscoveredService>> discoverAllLinqoraDevices() async {
    List<DiscoveredService> devices = [];
    Completer<List<DiscoveredService>> completer = Completer();

    try {
      onStatusChanged?.call(DiscoveryStatus.started);

      // Включаем мультикаст для Android
      final multicastEnabled = await _enableMulticast();
      if (!multicastEnabled) {
        completer.complete([]);
        return [];
      }

      _client = MDnsClient();
      await _client!.start();

      if (kDebugMode) {
        print('Начинаем mDNS-обнаружение для Linqora-устройств');
      }

      _discoveryTimer = Timer(Duration(seconds: discoveryTimeout), () {
        if (!completer.isCompleted) {
          _stopDiscovery();
          completer.complete(devices);
        }
      });

      // ПОСИК СТАНДАРТНОГО LINQORA СЕРВИСА
      try {
        if (kDebugMode) {
          print('Ищем Linqora сервисы с типом "_linqora._tcp.local"');
        }

        await for (final PtrResourceRecord ptr in _client!
            .lookup<PtrResourceRecord>(
              ResourceRecordQuery.serverPointer('_linqora._tcp.local'),
            )) {
          if (kDebugMode) {
            print('Найден Linqora сервис: ${ptr.domainName}');
          }

          // Обрабатываем найденный сервис
          await _processLinqoraInstance(ptr.domainName, devices);
        }
      } catch (e) {
        if (kDebugMode) {
          print('Ошибка при поиске стандартных Linqora сервисов: $e');
        }
      }

      // ПОИСК ЧЕРЕЗ DNS-SD
      if (devices.isEmpty) {
        try {
          if (kDebugMode) {
            print('Пробуем поиск через DNS-SD...');
          }

          // Находим все типы сервисов через DNS-SD
          await for (final PtrResourceRecord serviceType in _client!
              .lookup<PtrResourceRecord>(
                ResourceRecordQuery.serverPointer(
                  '_services._dns-sd._udp.local',
                ),
              )) {
            if (kDebugMode) {
              print(
                'Найден тип сервиса через DNS-SD: ${serviceType.domainName}',
              );
            }

            // Ищем экземпляры Linqora сервисов
            if (_isLinqoraServiceType(serviceType.domainName)) {
              await for (final PtrResourceRecord instance in _client!
                  .lookup<PtrResourceRecord>(
                    ResourceRecordQuery.serverPointer(serviceType.domainName),
                  )) {
                if (kDebugMode) {
                  print(
                    'Найден экземпляр ${serviceType.domainName}: ${instance.domainName}',
                  );
                }

                await _processLinqoraInstance(instance.domainName, devices);
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('Ошибка при поиске через DNS-SD: $e');
          }
        }
      }

      // Завершение поиска
      if (_discoveryTimer?.isActive ?? false) {
        _discoveryTimer!.cancel();
      }

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

      if (!completer.isCompleted) {
        completer.complete(devices);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Ошибка при поиске устройств: $e');
      }
      _stopDiscovery();
      completer.complete([]);
    }

    return completer.future;
  }

  // Метод для обработки найденного экземпляра Linqora сервиса
  Future<void> _processLinqoraInstance(
    String serviceName,
    List<DiscoveredService> devices,
  ) async {
    try {
      await for (final SrvResourceRecord srv in _client!
          .lookup<SrvResourceRecord>(
            ResourceRecordQuery.service(serviceName),
          )) {
        if (kDebugMode) {
          print('SRV запись: ${srv.target}:${srv.port}');
        }

        bool supportsTLS = false;
        String hostname = '';
        String osInfo = '';

        // Получаем TXT записи
        try {
          await for (final TxtResourceRecord txt in _client!
              .lookup<TxtResourceRecord>(
                ResourceRecordQuery.text(serviceName),
              )) {
            if (kDebugMode) {
              print('TXT запись: ${txt.text}');
            }

            // Обработка TXT записи с поддержкой разных форматов
            if (txt.text.contains('tls=true')) {
              supportsTLS = true;
            }

            // Попытка извлечь hostname и os
            final txtParts = txt.text.split(RegExp(r'[;\s]'));
            for (final part in txtParts) {
              final trimmedPart = part.trim();
              if (trimmedPart.isEmpty) continue;

              if (trimmedPart.startsWith('hostname=')) {
                hostname = trimmedPart.substring(9);
              } else if (trimmedPart.startsWith('os=')) {
                osInfo = trimmedPart.substring(3);
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('Ошибка при обработке TXT записей: $e');
          }
        }

        // Получаем IP адрес
        await for (final IPAddressResourceRecord ip in _client!
            .lookup<IPAddressResourceRecord>(
              ResourceRecordQuery.addressIPv4(srv.target),
            )) {
          if (kDebugMode) {
            print('Найден IP: ${ip.address.address}');
          }

          // Создаем понятное имя сервиса
          String serviceParts = serviceName.split('._')[0];
          if (serviceParts.startsWith('_')) {
            serviceParts = serviceParts.substring(1);
          }

          final device = DiscoveredService(
            id: serviceParts,
            name: hostname.isNotEmpty ? hostname : serviceParts,
            address: ip.address.address,
            port: srv.port.toString(),
            supportsTLS: supportsTLS,
            hostname: hostname,
            osInfo: osInfo,
          );

          if (!_deviceExists(devices, device)) {
            devices.add(device);
            onStatusChanged?.call(DiscoveryStatus.deviceFound);

            if (kDebugMode) {
              print(
                'Добавлено устройство: ${device.name} (${device.address}:${device.port})',
              );
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Ошибка при обработке сервиса $serviceName: $e');
      }
    }
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
