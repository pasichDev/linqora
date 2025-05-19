import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/data/enums/type_messages_ws.dart';
import 'package:linqoraremote/data/models/auth_response_handler.dart';
import 'package:linqoraremote/data/models/ws_message.dart';
import 'package:linqoraremote/data/providers/mdns_provider.dart';
import 'package:linqoraremote/data/providers/websocket_provider.dart';

import '../../core/constants/constants.dart';
import '../../core/utils/device_info.dart';
import '../../core/utils/error_handler.dart';
import '../../data/models/discovered_service.dart';
import '../../routes/app_routes.dart';

enum AuthStatus { noWifi, scanning, listDevices, pendingAuth, connecting }

class AuthController extends GetxController {
  final WebSocketProvider webSocketProvider;
  final MDnsProvider mDnsProvider;

  AuthController({required this.webSocketProvider, required this.mDnsProvider});

  final RxList<DiscoveredService> discoveredDevices = <DiscoveredService>[].obs;
  final RxString statusMessage = ''.obs;
  final RxInt authTimeoutSeconds = 30.obs;
  final Rxn<DiscoveredService> authDevice = Rxn<DiscoveredService>();
  final Rx<AuthStatus> authStatus = AuthStatus.scanning.obs;
  final RxBool isWifiConnections = false.obs;
  Timer? _authTimer;

  late final Stream<ConnectivityResult> _connectivityStream;

  @override
  void onInit() {
    _setupMDnsProvider();
    _loadSettingsApp();
    super.onInit();
  }

  Future<void> _loadSettingsApp() async {
    _connectivityStream = Connectivity().onConnectivityChanged.map(
      (result) => result.first,
    );

    _connectivityStream.listen((result) {
      switch (result) {
        case ConnectivityResult.wifi:
          _returnWifiConnection();
          break;
        default:
          _cancelWifiConnection();
          break;
      }
    });
  }

  _cancelWifiConnection() async {
    isWifiConnections.value = false;
    await _notConnectDevice(isError: false);
    authStatus.value = AuthStatus.noWifi;
  }

  _returnWifiConnection() {
    isWifiConnections.value = true;
    authStatus.value = AuthStatus.scanning;
    startDiscovery();
  }

  void _setupMDnsProvider() {
    mDnsProvider.onStatusChanged = (status, {String? message}) {
      switch (status) {
        case DiscoveryStatus.started:
          authStatus.value = AuthStatus.scanning;
          break;
        case DiscoveryStatus.deviceFound:
          statusMessage.value = 'Найдено устройства!';
          break;
        case DiscoveryStatus.completed:
          authStatus.value = AuthStatus.listDevices;
          break;
        case DiscoveryStatus.empty:
          authStatus.value = AuthStatus.listDevices;
          break;
        case DiscoveryStatus.error:
          showErrorSnackbar(
            "Ошибка поиска устройств",
            message ?? 'Ошибка поиска устройства не определена',
          );
          authStatus.value = AuthStatus.listDevices;
          break;
        case DiscoveryStatus.timeout:
          authStatus.value = AuthStatus.listDevices;
          break;
      }
    };
  }

  @override
  void onClose() {
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
      }
    } catch (e) {
      statusMessage.value = 'Ошибка при поиске устройств: $e';
      authStatus.value = AuthStatus.listDevices;
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
      _notConnectDevice(errorMessage: error.toString().split('\n').first);
    };

    try {
      await webSocketProvider.connect(
        device,
        allowSelfSigned: allowSelfSigned,
        timeout: const Duration(seconds: 8),
      );
    } catch (e) {
      if (kDebugMode) print("connect Exception: $e");
      _notConnectDevice(errorMessage: e.toString().split('\n').first);
    }
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
          'versionClient': await getAppVersion(),
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

    AuthResponse authResponse;
    try {
      authResponse = AuthResponse.fromJson(response);
    } catch (e) {
      cancelAuth('Error parsing auth response: $e');
      return;
    }
    switch (authResponse.code) {
      // Успешная авторизация - устройство уже авторизовано
      case AuthStatusCode.authorized || AuthStatusCode.approved:
        webSocketProvider.setAuthenticated(true);
        _navigateToDeviceHome();
        break;

      // Авторизация отклонена хостом
      case AuthStatusCode.rejected ||
          AuthStatusCode.invalidFormat ||
          AuthStatusCode.missingDeviceID ||
          AuthStatusCode.timeout ||
          AuthStatusCode.requestFailed:
        cancelAuth(authResponse.localMessage);
        break;

      case AuthStatusCode.unsupportedVersion:
        cancelAuth(authResponse.localMessage);

      case AuthStatusCode.notAuthorized:
        break;

      default:
        cancelAuth(
          'Неизвестная ошибка авторизации (код: ${authResponse.code})',
        );

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
    switch (authResponse.code) {
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

  void _navigateToDeviceHome() {
    if (authDevice.value == null) {
      showErrorSnackbar(
        'Ошибка',
        "Невозможно перейти на страницу устройства: нет информации об устройстве",
      );

      return;
    }

    _cleanupResources(resetStatus: true, clearHandlers: true);
    statusMessage.value = '';

    Get.toNamed(
      AppRoutes.DEVICE_HOME,
      arguments: {'device': authDevice.value!.toJson()},
    );
  }

  void cancelAuth([String? reason]) {
    _cleanupResources(
      resetStatus: true,
      clearHandlers: true,
      disconnectWebSocket: true,
    );

    if (reason != null) {
      showErrorSnackbar('Ошибка авторизации', reason);
    }
  }

  Future<void> _notConnectDevice({
    String errorMessage = 'Не удалось подключиться к устройству',
    bool isError = true,
  }) async {
    _cleanupResources(resetStatus: true);

    if (isError) {
      showErrorSnackbar('Ошибка подключения', errorMessage);
    } else {
      statusMessage.value = 'Соединение прервано';
    }
  }

  void _cleanupResources({
    bool resetStatus = true,
    bool clearHandlers = true,
    bool disconnectWebSocket = false,
  }) {
    if (clearHandlers) {
      webSocketProvider.removeHandler(TypeMessageWs.auth_response.value);
      webSocketProvider.removeHandler(TypeMessageWs.auth_pending.value);
    }

    if (resetStatus) {
      authStatus.value = AuthStatus.listDevices;
    }

    if (disconnectWebSocket) {
      webSocketProvider.disconnect();
    }
  }
}
