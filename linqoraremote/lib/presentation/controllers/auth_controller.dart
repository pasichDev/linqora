import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:linqoraremote/data/enums/type_request_host.dart';
import 'package:linqoraremote/data/models/auth_response_handler.dart';
import 'package:linqoraremote/data/models/ws_message.dart';
import 'package:linqoraremote/data/providers/mdns_provider.dart';
import 'package:linqoraremote/data/providers/websocket_provider.dart';
import 'package:linqoraremote/data/services/secure_storage_service.dart';

import '../../core/constants/constants.dart';
import '../../core/constants/settings.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/auth_response_handler.dart';
import '../../core/utils/device_info.dart';
import '../../core/utils/error_handler.dart';
import '../../data/models/discovered_service.dart';
import '../../data/models/server_response.dart';
import '../../routes/app_routes.dart';

enum AuthStatus { noWifi, scanning, listDevices, pendingAuth, connecting }

class AuthController extends GetxController {
  final WebSocketProvider webSocketProvider;
  final MDnsProvider mDnsProvider;

  AuthController({required this.webSocketProvider, required this.mDnsProvider});

  final RxList<MdnsDevice> discoveredDevices = <MdnsDevice>[].obs;
  final RxInt authTimeoutSeconds = 30.obs;
  final Rxn<MdnsDevice> authDevice = Rxn<MdnsDevice>();
  final Rx<AuthStatus> authStatus = AuthStatus.listDevices.obs;
  final RxBool isWifiConnections = false.obs;
  final RxBool isAutoConnectEnable = false.obs;
  Timer? _authTimer;
  StreamSubscription<ConnectivityResult>? _connectivitySub;

  late final Stream<ConnectivityResult> _connectivityStream;

  @override
  void onInit() {
    /// Get the last connected device
    _setupMDnsProvider();

    /// Get the last connected device
    _loadSettingsApp();

    super.onInit();
  }

  /// Load settings from storage
  Future<void> _loadSettingsApp() async {
    _connectivityStream = Connectivity().onConnectivityChanged.map(
      (result) => result.first,
    );

    // Store the subscription so we can cancel it in onClose() and avoid leaks.
    _connectivitySub = _connectivityStream.listen((result) {
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

  /// Setup mDNS provider
  void _setupMDnsProvider() {
    mDnsProvider.onStatusChanged = (status, {String? message}) {
      switch (status) {
        case DiscoveryStatus.started:
          authStatus.value = AuthStatus.scanning;
          break;
        case DiscoveryStatus.deviceFound:
          break;
        case DiscoveryStatus.completed:
          authStatus.value = AuthStatus.listDevices;
          break;
        case DiscoveryStatus.empty:
          authStatus.value = AuthStatus.listDevices;
          break;
        case DiscoveryStatus.error:
          showErrorSnackbar(
            'error_search_device'.tr,
            message ?? 'error_unknown_device'.tr,
          );
          authStatus.value = AuthStatus.listDevices;
          break;
      }
    };
  }

  /// Get the last connected device
  void _fetchLastConnect() {
    try {
      final mIsAutoConnectEnable =
          GetStorage(
            SettingsConst.kSettings,
          ).read<bool>(SettingsConst.kEnableAutoConnect) ??
          false;
      isAutoConnectEnable.value = mIsAutoConnectEnable;

      if (mIsAutoConnectEnable) {
        // Read explicitly as dynamic first to avoid a TypeError when the stored
        // value is absent or corrupted (e.g. empty string from an older build).
        final raw = GetStorage(SettingsConst.kSettings)
            .read<dynamic>(SettingsConst.kLastConnect);

        if (raw == null || raw is! Map<String, dynamic>) {
          AppLogger.release(
            'No valid last-connect data found, starting discovery',
            module: "AuthController",
          );
          isAutoConnectEnable.value = false;
          authStatus.value = AuthStatus.scanning;
          startDiscovery();
          return;
        }

        final lastDevice = MdnsDevice.fromJson(raw);
        AppLogger.release(
          'Autoconnect to ${lastDevice.name}',
          module: "AuthController",
        );

        discoveredDevices.add(lastDevice);
        connectToDevice(lastDevice);
      } else {
        authStatus.value = AuthStatus.scanning;
        startDiscovery();
      }
    } catch (e) {
      isAutoConnectEnable.value = false;
      authStatus.value = AuthStatus.scanning;
      startDiscovery();
    }
  }

  @override
  void onClose() {
    _authTimer?.cancel();
    _connectivitySub?.cancel(); // prevent StreamSubscription memory leak
    super.onClose();
  }

  /// Start discovery of devices
  Future<void> startDiscovery() async {
    discoveredDevices.clear();
    authStatus.value = AuthStatus.scanning;

    try {
      final devices = await mDnsProvider.discoverLinqoraDevices();

      if (devices.isNotEmpty) {
        discoveredDevices.addAll(devices);
        authStatus.value = AuthStatus.listDevices;
      } else {
        authStatus.value = AuthStatus.listDevices;
      }
    } catch (e) {
      AppLogger.release(
        'Error searching devices: $e',
        module: "AuthController",
      );
      showErrorSnackbar('error_search_device'.tr, '$e');
      authStatus.value = AuthStatus.listDevices;
    }
  }

  /// Connect to the selected device
  Future<void> connectToDevice(MdnsDevice device) async {
    if (authStatus.value == AuthStatus.connecting) return;
    authDevice.value = device;
    authStatus.value = AuthStatus.connecting;

    webSocketProvider.onAuthStatusChanged = (status, {String? message}) {
      switch (status) {
        case WebSocketState.hold:
          break;
        case WebSocketState.connected:
          if (authStatus.value != AuthStatus.connecting) {
            return;
          }
          startAuthProcess();
          break;
        case WebSocketState.error:
          _notConnectDevice(errorMessage: message.toString().split('\n').first);
          break;
        case WebSocketState.disconnected:
          _notConnectDevice();
          break;
      }
    };

    /// Add delay for smooth display of ui
    await Future.delayed(const Duration(seconds: 2));

    try {
      await webSocketProvider.connect(
        device,
        allowSelfSigned: allowSelfSigned,
        timeout: const Duration(seconds: 8),
      );
    } catch (e) {
      AppLogger.release(
        'Connect to Device exception: $e',
        module: "AuthController",
      );
      _notConnectDevice(errorMessage: e.toString().split('\n').first);
    }
  }

  /// Connect to the device by IP address
  Future<void> connectToDeviceByIp(
    String ip,
    String port, {
    bool tls = true,
  }) async {
    final device = MdnsDevice(
      name: 'Manual Connection',
      address: ip,
      port: port,
      supportsTLS: tls,
    );
    await connectToDevice(device);
  }

  /// Start the authorization process
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
    webSocketProvider.registerHandler(
      TypeMessageWs.auth_challenge.value,
      _handleAuthChallenge,
    );

    /// Send the authorization request
    sendAuthRequest();

    /// Start the timer for the authorization process
    _authTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (authTimeoutSeconds.value > 0) {
        authTimeoutSeconds.value--;
      } else {
        cancelAuth('error_timeout_connection'.tr);
      }
    });
  }

  /// Send the authorization request
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

      webSocketProvider.sendMessage(message.toJson());
    } catch (e) {
      AppLogger.release(
        '${'error_send_auth_request'.tr}: $e',
        module: "AuthController",
      );
      cancelAuth('${'error_send_auth_request'.tr}: $e');
    }
  }

  /// Handle the authorization response
  void _handleAuthResponse(Map<String, dynamic> response) {
    _authTimer?.cancel();

    final serverResponse = ServerResponse<AuthData>.fromJson(
      response,
      (data) => AuthData.fromJson(data),
    );

    if (serverResponse.hasError) {
      cancelAuth(serverResponse.error!.message);
      return;
    }

    switch (serverResponse.data?.code) {
      // Authorization is successful
      case AuthStatusCode.authorized || AuthStatusCode.approved:
        _navigateToDeviceHome();
        break;

      // Authorization is cancelled host
      case AuthStatusCode.rejected ||
          AuthStatusCode.invalidFormat ||
          AuthStatusCode.missingDeviceID ||
          AuthStatusCode.timeout ||
          AuthStatusCode.requestFailed:
        cancelAuth(serverResponse.data?.localMessage);
        break;

      // Authorization is cancelled for unsupported version
      case AuthStatusCode.unsupportedVersion:
        cancelAuth(serverResponse.data?.localMessage);

      case AuthStatusCode.notAuthorized:
        break;

      default:
        AppLogger.release(
          'error_unknown_auth_request'.tr,
          module: "AuthController",
        );
        cancelAuth(
          '${'error_unknown_auth_request'.tr} : (${serverResponse.data?.code})',
        );

        break;
    }
  }

  /// Handle the pending authorization response
  void _handleAuthPending(Map<String, dynamic> response) {
    final serverResponse = ServerResponse<AuthData>.fromJson(
      response,
      (data) => AuthData.fromJson(data),
    );

    if (serverResponse.hasError) {
      cancelAuth(serverResponse.error!.message);
      return;
    }

    switch (serverResponse.data?.code) {
      case AuthStatusCode.pending:
        if (authStatus.value != AuthStatus.pendingAuth) {
          authStatus.value = AuthStatus.pendingAuth;
        }
        break;

      default:
        AppLogger.release(
          "${'error_unknown_auth_request'.tr} ${serverResponse.data!.message}",
          module: "AuthController",
        );
        cancelAuth(
          "${'error_unknown_auth_request'.tr} ${serverResponse.data!.message}",
        );
        break;
    }
  }

  /// Navigate to the device home screen
  void _navigateToDeviceHome() {
    if (authDevice.value == null) {
      showErrorSnackbar('error'.tr, 'error_no_info_navigate_home'.tr);
      return;
    }
    Get.toNamed(
      AppRoutes.DEVICE_HOME,
      arguments: {'device': authDevice.value!.toJson()},
    );

    /// Handler closing other screens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cleanupResources(resetStatus: true, clearHandlers: true);
    });

    /// Скасовуємо колбек який діяв при авторизації
    webSocketProvider.onAuthStatusChanged = null;
  }

  /// Cancel the authorization process
  void cancelAuth([String? reason]) {
    _cleanupResources(
      resetStatus: true,
      clearHandlers: true,
      disconnectWebSocket: true,
    );

    if (reason != null) {
      showErrorSnackbar('error_auth'.tr, reason);
    }
  }

  /// Handle the case when the device cannot be connected
  Future<void> _notConnectDevice({
    String errorMessage = "",
    bool isError = true,
  }) async {
    _cleanupResources(resetStatus: true);

    if (errorMessage.isEmpty) {
      errorMessage = 'error_auth_to_device'.tr;
    }

    if (isError) {
      showErrorSnackbar('error_connection'.tr, errorMessage);
    }
  }

  /// Cancel wifi connection
  _cancelWifiConnection() async {
    isWifiConnections.value = false;
    await _notConnectDevice(isError: false);
    authStatus.value = AuthStatus.noWifi;
  }

  /// Return wifi connection
  _returnWifiConnection() {
    isWifiConnections.value = true;
    _fetchLastConnect();
  }

  /// Handles a challenge issued by the server.
  /// Computes HMAC-SHA256(token, sharedSecret) and sends the response.
  Future<void> _handleAuthChallenge(Map<String, dynamic> response) async {
    final data = response['data'];
    final token = data is Map ? data['token'] as String? : null;

    if (token == null || token.isEmpty) {
      cancelAuth('error_send_auth_request'.tr);
      return;
    }

    final secret = await SecureStorageService.getSharedSecret();
    if (secret == null || secret.isEmpty) {
      AppLogger.release(
        'No shared secret stored — cannot respond to challenge',
        module: 'AuthController',
      );
      cancelAuth('error_send_auth_request'.tr);
      return;
    }

    final hmacBytes = Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(token));
    final hmacHex = hmacBytes.toString();

    final msg = WsMessage(type: TypeMessageWs.auth_challenge_response.value)
      ..setField('data', {'token': token, 'hmac': hmacHex});

    webSocketProvider.sendMessage(msg.toJson());
    AppLogger.release('Challenge response sent', module: 'AuthController');
  }

  /// Cleanup resources after auth process
  void _cleanupResources({
    bool resetStatus = true,
    bool clearHandlers = true,
    bool disconnectWebSocket = false,
  }) {
    if (clearHandlers) {
      webSocketProvider.removeHandler(TypeMessageWs.auth_response.value);
      webSocketProvider.removeHandler(TypeMessageWs.auth_pending.value);
      webSocketProvider.removeHandler(TypeMessageWs.auth_challenge.value);
    }

    if (resetStatus) {
      authStatus.value = AuthStatus.listDevices;
    }

    if (disconnectWebSocket) {
      webSocketProvider.disconnect();
    }
  }
}
