import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../core/constants/constants.dart';
import '../../data/enums/type_messages_ws.dart';
import '../../data/models/auth_response.dart';
import '../../data/models/discovered_service.dart';
import '../../data/models/ws_message.dart';
import '../../data/providers/mdns_provider.dart';
import '../../data/providers/websocket_provider.dart';
import '../../utils/device_info.dart';

enum MDnsStatus { connecting, connected, cancel, ws, retry }

class DeviceHomeController extends GetxController {
  final MDnsProvider mdnsProvider;
  final WebSocketProvider webSocketProvider;

  DeviceHomeController({
    required this.mdnsProvider,
    required this.webSocketProvider,
  });

  final RxBool isConnected = false.obs;
  final Rx<MDnsStatus> mdnsConnectingStatus = MDnsStatus.connecting.obs;
  final RxList<DiscoveredService> devices = <DiscoveredService>[].obs;
  final RxString deviceCode = '0'.obs;
  final RxInt selectedMenuIndex = (-1).obs;
  final Rx<AuthInformation?> authInformation = Rx<AuthInformation?>(null);

  // Maximum retry attempts
  static const int maxRetryAttempts = 2;
  static const Duration retryDelay = Duration(seconds: 3);
  int _discoveryAttempts = 0;
  Timer? _retryTimer;

  @override
  void onInit() {
    super.onInit();
    var args = Get.arguments;
    if (args != null) {
      deviceCode.value = args['deviceCode'] ?? '';
    }
    _setupMDnsProvider();
    startDiscovery();
  }

  @override
  void onClose() {
    webSocketProvider.close();
    _retryTimer?.cancel();
    mdnsProvider.dispose();
    super.onClose();
  }

  void _setupMDnsProvider() {
    mdnsProvider.onStatusChanged = (status, {String? message}) {
      switch (status) {
        case DiscoveryStatus.started:
          mdnsConnectingStatus.value = MDnsStatus.connecting;
          break;
        case DiscoveryStatus.deviceFound:
          mdnsConnectingStatus.value = MDnsStatus.connected;
          break;
        case DiscoveryStatus.empty:
        case DiscoveryStatus.timeout:
          _handleEmptyOrTimeout();
          break;
        case DiscoveryStatus.error:
          _handleDiscoveryError(message);
          break;
        case DiscoveryStatus.completed:
          // Handled in discovery result
          break;
      }
    };
  }

  void startDiscovery() {
    _discoveryAttempts = 0;
    _performDiscovery();
  }

  void _performDiscovery() async {
    _discoveryAttempts++;
    if (kDebugMode) {
      print('Discovery attempt #$_discoveryAttempts');
    }

    try {
      devices.value = await mdnsProvider.discoverDevices(deviceCode.value);

      if (devices.isNotEmpty && devices[0].address != null) {
        await connectToDevice(devices[0].copyWith(authCode: deviceCode.value));
      } else {
        _handleEmptyOrTimeout();
      }
    } catch (e) {
      if (kDebugMode) {
        print(
          'Error during device discovery (attempt #$_discoveryAttempts): $e',
        );
      }
      _handleDiscoveryError('Discovery error: $e');
    }
  }

  void _handleEmptyOrTimeout() {
    if (_discoveryAttempts < maxRetryAttempts) {
      mdnsConnectingStatus.value = MDnsStatus.retry;
      _scheduleRetry();
    } else {
      mdnsConnectingStatus.value = MDnsStatus.cancel;
      _handleDiscoveryFailure();
    }
  }

  void _handleDiscoveryError(String? message) {
    if (_discoveryAttempts < maxRetryAttempts) {
      mdnsConnectingStatus.value = MDnsStatus.retry;
      _scheduleRetry();
    } else {
      mdnsConnectingStatus.value = MDnsStatus.cancel;
      _handleDiscoveryFailure();
    }
    if (message != null) {
      Get.snackbar('Error', message, snackPosition: SnackPosition.BOTTOM);
    }
  }

  void _scheduleRetry() {
    if (kDebugMode) {
      print('Scheduling retry in ${retryDelay.inSeconds} seconds');
    }
    _retryTimer?.cancel();
    _retryTimer = Timer(retryDelay, () {
      if (mdnsConnectingStatus.value == MDnsStatus.retry) {
        _performDiscovery();
      }
    });
  }

  void _handleDiscoveryFailure() {
    if (kDebugMode) {
      print('All discovery attempts failed ($maxRetryAttempts attempts)');
    }
    Get.back(result: {'status': 'cancel'});
    Get.snackbar(
      'Device Unavailable',
      'Connection failed after $maxRetryAttempts attempts',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void retryDiscovery() {
    if (_discoveryAttempts < maxRetryAttempts) {
      _performDiscovery();
    } else {
      _handleDiscoveryFailure();
    }
  }

  Future<void> connectToDevice(DiscoveredService device) async {
    webSocketProvider.onConnected = () {
      isConnected.value = true;
      mdnsConnectingStatus.value = MDnsStatus.ws;
    };

    webSocketProvider.onDisconnected = () {
      isConnected.value = false;
      if (mdnsConnectingStatus.value == MDnsStatus.ws) {
        Get.back(result: {'status': 'cancel'});
        Get.snackbar(
          'Connection Lost',
          'LinqoraHost is inactive',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    };

    if (device.address != null && device.port != null) {
      final isWsConnect = await webSocketProvider.connect(
        device,
        allowSelfSigned: allowSelfSigned,
      );

      if (!isWsConnect) {
        await webSocketProvider.disconnect();
        Get.snackbar(
          'Ws connect failed',
          'Please check your device online and try again.',
          snackPosition: SnackPosition.BOTTOM,
        );
        cancelConnection();
      }

      final authenticated = await authenticate();
      if (!authenticated) {
        if (kDebugMode) {
          print('Authentication failed');
        }
        await webSocketProvider.disconnect();
        Get.snackbar(
          'Authentication failed',
          'Please check your device code and try again.',
          snackPosition: SnackPosition.BOTTOM,
        );
        cancelConnection();
      }
    } else {
      await webSocketProvider.disconnect();
    }
  }

  Future<bool> authenticate() async {
    var deviceName = await getDeviceName();
    if (!webSocketProvider.isConnected ||
        !isConnected.value ||
        mdnsConnectingStatus.value != MDnsStatus.ws) {
      if (kDebugMode) {
        print('Cannot authenticate: no connection');
      }
      return false;
    }

    try {
      final completer = Completer<bool>();
      final authMessage = WsMessage(
        type: TypeMessageWs.auth.value,
        deviceCode: deviceCode.value,
      )..setField('data', {'deviceName': deviceName});

      webSocketProvider.registerHandler('auth_response', (data) {
        final success = data['success'] as bool;
        if (success) {
          authInformation.value = AuthResponse.fromJson(data).authInformation;
          webSocketProvider.setAuthenticated(true);
          webSocketProvider.joinRoom('auth');
          completer.complete(true);
        } else {
          completer.complete(false);
        }
        webSocketProvider.removeHandler('auth_response');
      });

      webSocketProvider.sendMessage(authMessage);

      Timer(Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          completer.complete(false);
          webSocketProvider.removeHandler('auth_response');
          webSocketProvider.close();
          cancelConnection();
        }
      });

      return await completer.future;
    } catch (e) {
      webSocketProvider.close();
      cancelConnection();
      return false;
    }
  }

  void cancelConnection() {
    isConnected.value = false;
    mdnsConnectingStatus.value = MDnsStatus.cancel;
    Get.back(result: {'status': 'cancel'});
  }

  void selectMenuItem(int index) {
    selectedMenuIndex.value = index;
  }
}
