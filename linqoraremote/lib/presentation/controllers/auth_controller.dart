import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/data/enums/type_messages_ws.dart';
import 'package:linqoraremote/data/models/auth_response_handler.dart';
import 'package:linqoraremote/data/models/ws_message.dart';
import 'package:linqoraremote/data/providers/mdns_provider.dart';
import 'package:linqoraremote/data/providers/websocket_provider.dart';

import '../../core/constants/constants.dart';
import '../../core/utils/device_info.dart';
import '../../data/models/discovered_service.dart';
import '../../routes/app_routes.dart';

enum AuthStatus { scanning, listDevices, pendingAuth, connecting }

class AuthController extends GetxController {
  final WebSocketProvider webSocketProvider;
  final MDnsProvider mDnsProvider;

  AuthController({required this.webSocketProvider, required this.mDnsProvider});

  final RxList<DiscoveredService> discoveredDevices = <DiscoveredService>[].obs;
  final RxString statusMessage = ''.obs;
  final RxInt authTimeoutSeconds = 30.obs;
  final Rxn<DiscoveredService> authDevice = Rxn<DiscoveredService>();
  final Rx<AuthStatus> authStatus = AuthStatus.scanning.obs;

  Timer? _scanTimer;
  Timer? _authTimer;

  @override
  void onInit() {
    _setupMDnsProvider();
    super.onInit();
  }

  void _setupMDnsProvider() {
    mDnsProvider.onStatusChanged = (status, {String? message}) {
      if (kDebugMode) {
        print("MDNS status changed: $status, message: $message");
      }
      switch (status) {
        case DiscoveryStatus.started:
          statusMessage.value = 'Поиск устройств в сети...';
          authStatus.value = AuthStatus.scanning;
          break;
        case DiscoveryStatus.deviceFound:
          statusMessage.value = 'Найдено устройства!';
          _scanTimer?.cancel();
          break;
        case DiscoveryStatus.completed:
          statusMessage.value = 'Поиск завершен';
          authStatus.value = AuthStatus.listDevices;
          break;
        case DiscoveryStatus.empty:
          statusMessage.value = 'Устройства не найдены';
          authStatus.value = AuthStatus.listDevices;
          break;
        case DiscoveryStatus.error:
          statusMessage.value = message ?? 'Ошибка поиска устройств';
          authStatus.value = AuthStatus.listDevices;
          break;
        case DiscoveryStatus.timeout:
          statusMessage.value = 'Время поиска истекло';
          authStatus.value = AuthStatus.listDevices;
          break;
      }
    };
  }

  @override
  void onClose() {
    _scanTimer?.cancel();
    _authTimer?.cancel();
    super.onClose();
  }

  Future<void> startDiscovery() async {
    discoveredDevices.clear();
    authStatus.value = AuthStatus.scanning;

    try {
      final devices = await mDnsProvider.discoverLinqoraDevices();

      if (devices.isNotEmpty) {
        discoveredDevices.addAll(devices);
        statusMessage.value = 'Найдено ${devices.length} устройств';
        authStatus.value = AuthStatus.listDevices;
      } else {
        statusMessage.value = 'Устройства не найдены';
        authStatus.value = AuthStatus.listDevices;

        // Устанавливаем автоматический повторный поиск
        _scanTimer?.cancel();
        _scanTimer = Timer(const Duration(seconds: 60), startDiscovery);
      }
    } catch (e) {
      statusMessage.value = 'Ошибка при поиске устройств: $e';
      authStatus.value = AuthStatus.listDevices; // Показываем пустой список
    }
  }

  Future<void> connectToDevice(DiscoveredService device) async {
    if (authStatus.value == AuthStatus.connecting) return;
    authDevice.value = device;
    authStatus.value = AuthStatus.connecting;
    statusMessage.value = 'Подключение к ${device.name}...';

    // Устанавливаем обработчики до попытки подключения
    webSocketProvider.onConnected = () {
      if (authStatus.value != AuthStatus.connecting) {
        return;
      }
      statusMessage.value =
          'Соединение установлено, выполняется авторизация...';
      startAuthProcess();
      if (kDebugMode) print("onConnected");
    };

    webSocketProvider.onDisconnected = () {
      if (kDebugMode) print("onDisconnected");
      _notConnectDevice();
    };

    webSocketProvider.onError = (error) {
      if (kDebugMode) print("onError: $error");
      _notConnectDevice(
        errorMessage:
            error.toString().split('\n').first,
      );
    };

    try {
      await webSocketProvider.connect(
        device,
        allowSelfSigned: allowSelfSigned,
        timeout: const Duration(seconds: 8),
      );
    } catch (e) {
      if (kDebugMode) print("connect Exception: $e");
      _notConnectDevice(
        errorMessage: e.toString().split('\n').first,
      );
    }
  }

  void _notConnectDevice({
    String errorMessage = 'Не удалось подключиться к устройству',
  }) {
    authStatus.value = AuthStatus.listDevices;
    statusMessage.value = errorMessage;
    statusMessage.value = 'Соединение прервано';
    _authTimer?.cancel();
    _scanTimer?.cancel();
    Get.snackbar(
      'Ошибка авторизации',
      errorMessage,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.orange.shade800,
      colorText: Colors.white,
    );
  }

  void startAuthProcess() {
    authTimeoutSeconds.value = 30;

    webSocketProvider.registerHandler(
      TypeMessageWs.auth_response.value,
      _handleAuthResponse,
    );
    webSocketProvider.registerHandler(
      TypeMessageWs.auth_pending.value,
      _handleAuthPending,
    );

    // Отправляем запрос на авторизацию
    sendAuthRequest();

    // Запускаем таймер для отсчета времени ожидания
    _authTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (authTimeoutSeconds.value > 0) {
        authTimeoutSeconds.value--;
      } else {
        cancelAuth('Время ожидания авторизации истекло');
      }
    });
  }

  void sendAuthRequest() async {
    try {
      final deviceName = await getDeviceName();

      final message = WsMessage(type: TypeMessageWs.auth_request.value)
        ..setField('data', {
          'deviceName': deviceName,
          'deviceId':
              Platform.isAndroid
                  ? 'android_${await getDeviceId()}'
                  : 'ios_${await getDeviceId()}',
          'ip': await getLocalIpAddress(),
        });

      if (kDebugMode) {
        print('Sending auth request: ${jsonEncode(message)}');
      }
      webSocketProvider.sendMessage(message.toJson());
    } catch (e) {
      cancelAuth('Ошибка при отправке запроса авторизации: $e');
    }
  }

  void _handleAuthResponse(Map<String, dynamic> response) {
    _authTimer?.cancel();

    if (kDebugMode) {
      print("Auth response received: $response");
    }
    AuthResponse authResponse;
    try {
      authResponse = AuthResponse.fromJson(response);
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing auth response: $e');
      }
      cancelAuth('Error parsing auth response: $e');
      return;
    }
    switch (authResponse.codeResponse) {
      // Успешная авторизация - устройство уже авторизовано
      case AuthStatusCode.authorized:
        webSocketProvider.setAuthenticated(true);
        _navigateToDeviceHome(authResponse.extra);
        break;

      // Авторизация только что подтверждена
      case AuthStatusCode.approved:
        webSocketProvider.setAuthenticated(true);
        _navigateToDeviceHome(authResponse.extra);
        break;

      // Авторизация отклонена администратором
      case AuthStatusCode.rejected:
        cancelAuth(AuthResponseHandler.getAuthMessage(AuthStatusCode.rejected));
        break;

      // Неверный формат данных авторизации
      case AuthStatusCode.invalidFormat:
        cancelAuth(
          AuthResponseHandler.getAuthMessage(AuthStatusCode.invalidFormat),
        );
        break;

      // Отсутствует ID устройства
      case AuthStatusCode.missingDeviceID:
        cancelAuth(
          AuthResponseHandler.getAuthMessage(AuthStatusCode.missingDeviceID),
        );
        break;

      // Время ожидания ответа истекло
      case AuthStatusCode.timeout:
        cancelAuth(AuthResponseHandler.getAuthMessage(AuthStatusCode.timeout));
        break;

      // Ошибка запроса авторизации на стороне сервера
      case AuthStatusCode.requestFailed:
        cancelAuth(
          AuthResponseHandler.getAuthMessage(AuthStatusCode.requestFailed),
        );
        break;

      // Устройство не авторизовано
      case AuthStatusCode.notAuthorized:
        // Продолжаем ожидать авторизацию
        break;

      // Обработка неизвестных кодов
      default:
        if (authResponse.success) {
          webSocketProvider.setAuthenticated(true);
          _navigateToDeviceHome(authResponse.extra);
        } else {
          cancelAuth(
            'Неизвестная ошибка авторизации (код: ${authResponse.extra})',
          );
        }
        break;
    }
  }

  /// Обработчик уведомлений о статусе ожидания авторизации
  void _handleAuthPending(Map<String, dynamic> response) {
    if (kDebugMode) {
      print("Auth pending response: $response");
    }

    AuthResponse authResponse;
    try {
      authResponse = AuthResponse.fromJson(response);
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing auth response: $e');
      }
      cancelAuth('Error parsing auth response: $e');
      return;
    }
    switch (authResponse.codeResponse) {
      // Ожидание авторизации (стандартный случай)
      case AuthStatusCode.pending:
        statusMessage.value = 'Ожидание подтверждения на устройстве хоста...';

        if (authStatus.value != AuthStatus.pendingAuth) {
          authStatus.value = AuthStatus.pendingAuth;
        }
        break;

      default:
        statusMessage.value =
            authResponse.message.isNotEmpty
                ? authResponse.message
                : 'Ожидание авторизации...';
        break;
    }
  }

  /// Вспомогательный метод для навигации к главному экрану
  void _navigateToDeviceHome(Map<String, dynamic>? hostInfo) {
    // Отменяем таймеры
    _scanTimer?.cancel();
    _authTimer?.cancel();

    if (authDevice.value == null) {
      if (kDebugMode) {
        print(
          'Невозможно перейти на страницу устройства: нет информации об устройстве',
        );
      }
      return;
    }
    authStatus.value = AuthStatus.listDevices;
    statusMessage.value = '';

    // Очистка обработчиков сообщений WebSocket
    webSocketProvider.removeHandler(TypeMessageWs.auth_response.value);
    webSocketProvider.removeHandler(TypeMessageWs.auth_pending.value);
    Get.toNamed(
      AppRoutes.DEVICE_HOME,
      arguments: {
        'device': authDevice.value!.toJson(),
        'hostInfo': hostInfo ?? {},
      },
    );
  }

  void cancelAuth([String? reason]) {
    _authTimer?.cancel();
    webSocketProvider.removeHandler('auth_response');
    webSocketProvider.removeHandler('auth_pending');
    webSocketProvider.disconnect();

    authStatus.value = AuthStatus.listDevices;

    if (reason != null) {
      statusMessage.value = reason;
      Get.snackbar(
        'Ошибка авторизации',
        reason,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.shade800,
        colorText: Colors.white,
      );
    }
  }
}
