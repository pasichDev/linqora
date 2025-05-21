import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:linqoraremote/data/enums/type_request_host.dart';
import 'package:linqoraremote/data/models/discovered_service.dart';
import 'package:linqoraremote/data/models/host_info.dart';
import 'package:linqoraremote/data/models/ws_message.dart';
import 'package:linqoraremote/services/background_service.dart';

import '../../core/constants/constants.dart';
import '../../core/constants/settings.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/error_handler.dart';
import '../../data/models/server_response.dart';
import '../../data/providers/websocket_provider.dart';
import '../../services/permissions_service.dart';

class DeviceHomeController extends GetxController with WidgetsBindingObserver {
  final WebSocketProvider webSocketProvider;

  DeviceHomeController({required this.webSocketProvider});

  final RxBool isConnected = false.obs;
  final RxInt selectedMenuIndex = (-1).obs;
  final RxBool isBackgroundServiceRunning = false.obs;
  final RxBool isReconnecting = false.obs;
  final RxBool showHostFull = false.obs;
  final RxMap deviceInfo = {}.obs;
  final Rxn<HostSystemInfo> hostInfo = Rxn<HostSystemInfo>();
  final Rxn<MdnsDevice> authDevice = Rxn<MdnsDevice>();

  DateTime _refreshLastTime = DateTime.now();
  Timer? _serviceStatusTimer;

  @override
  Future<void> onInit() async {
    super.onInit();

    /// Get the device information from the arguments
    await _setupFromArguments();

    /// Load the settings
    _loadingSettings();

    /// Set up the WebSocket handlers
    _setupWebSocketHandlers();

    /// Set up the background service handlers
    _startServiceStatusCheck();

    /// Set up the background service handlers
    setupBackgroundServiceHandlers();

    /// Start the background service if needed
    _startBackgroundServiceIfNeeded();
  }

  @override
  void onClose() {
    stopBackgroundService();
    _serviceStatusTimer?.cancel();
    webSocketProvider.removeHandler(TypeMessageWs.host_info.value);
    BackgroundConnectionService.removeMessageHandler(
      _handleBackgroundServiceMessage,
    );

    super.onClose();
  }

  /// Get settings from storage
  void _loadingSettings() {
    try {
      showHostFull.value =
          GetStorage(
            SettingsConst.kSettings,
          ).read<bool>(SettingsConst.kShowHostInfo) ??
          true;
    } catch (e) {
      AppLogger.release(
        'Error loading settings: $e',
        module: "DeviceHomeController",
      );
    }
  }

  /// Start the background service if needed
  void _startBackgroundServiceIfNeeded() async {
    if (authDevice.value != null && isConnected.value) {
      final deviceName = authDevice.value!.name;
      final deviceAddress =
          "${authDevice.value!.address}:${authDevice.value!.port}";
      final notificationsSettings =
          GetStorage(
            SettingsConst.kSettings,
          ).read<bool>(SettingsConst.kEnableNotifications) ??
          false;

      final statusDevicePermission =
          await PermissionsService.checkNotificationPermission();

      /// Start the background service
      await BackgroundConnectionService.startService(
        deviceName,
        deviceAddress,
        isConnected.value,
      );

      /// Force update device info
      Future.delayed(const Duration(seconds: 3), () {
        BackgroundConnectionService.forceUpdateDeviceInfo(
          deviceName,
          deviceAddress,
          isConnected.value,
          notificationsSettings && statusDevicePermission,
        );
      });
    }
  }

  /// Method to start background handlers
  void setupBackgroundServiceHandlers() {
    BackgroundConnectionService.addMessageHandler(
      _handleBackgroundServiceMessage,
    );
  }

  /// Method to handle messages from the background service
  void _handleBackgroundServiceMessage(String message) {
    if (message == BackgroundConnectionService.MESSAGE_CHECK_CONNECTION) {
      _checkConnection();
    } else if (message == BackgroundConnectionService.MESSAGE_CONNECTION_LOST) {
      if (webSocketProvider.isConnected) {
        _checkConnection(forcePing: true);
      }
    }
  }

  /// Check the connection status
  void _checkConnection({bool forcePing = false}) {
    if (!webSocketProvider.isConnected && !forcePing) {
      BackgroundConnectionService.reportConnectionState(false);
      return;
    }

    webSocketProvider.sendPing();
  }

  /// Method to handle the background service message
  Future<void> _setupFromArguments() async {
    final args = Get.arguments;

    if (args != null && args['device'] != null) {
      if (args['device'] != null) {
        try {
          authDevice.value = MdnsDevice.fromJson(args['device']);
          GetStorage(
            SettingsConst.kSettings,
          ).write(SettingsConst.kLastConnect, authDevice.value!.toJson());
        } catch (e) {
          AppLogger.release(
            'Error parse device data: ${args['device']}',
            module: "DeviceHomeController",
          );
        }
      }

      isConnected.value = webSocketProvider.isConnected;
    }
  }

  /// Method to set up WebSocket handlers
  void _setupWebSocketHandlers() {
    webSocketProvider.onDisconnected = () {
      showErrorSnackbar(
        'connection_broken'.tr,
        'connection_broken_description'.tr,
      );
      disconnectFromDevice();
    };

    webSocketProvider.registerHandler(
      TypeMessageWs.host_info.value,
      _handleSystemInfo,
    );

    _requestSystemInfo();
  }

  /// Method to start the background service
  void _startServiceStatusCheck() {
    _serviceStatusTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      isBackgroundServiceRunning.value =
          await BackgroundConnectionService.isRunning();
    });
  }

  /// Stop the background service
  Future<void> stopBackgroundService() async {
    try {
      await BackgroundConnectionService.stopService();
      isBackgroundServiceRunning.value = false;
      AppLogger.release(
        'Background service stopped',
        module: "DeviceHomeController",
      );
    } catch (e) {
      AppLogger.release(
        'Error stopping background service: $e',
        module: "DeviceHomeController",
      );
    }
  }

  /// Method to refresh the host information
  void refreshHostInfo() {
    bool difference =
        DateTime.now().difference(_refreshLastTime).inSeconds >= 30;
    if (isConnected.value && difference) {
      _requestSystemInfo();
    }
  }

  /// Request system information
  void _requestSystemInfo() {
    if (!isConnected.value) return;
    _refreshLastTime = DateTime.now();
    try {
      webSocketProvider.sendMessage(
        WsMessage(type: TypeMessageWs.host_info.value),
      );
    } catch (e) {
      AppLogger.release(
        'Error stopping system info: $e',
        module: "DeviceHomeController",
      );
    }
  }

  /// Method to handle the system information response
  void _handleSystemInfo(Map<String, dynamic> data) {
    try {
      final response = ServerResponse<HostSystemInfo>.fromJson(
        data,
        (json) => HostSystemInfo.fromJson(json),
      );

      if (response.hasError) {
        showErrorSnackbar(
          'error_fetch_data'.tr,
          '${'error_fetch_data_description'.tr} ${response.error?.message}',
        );
        return;
      }
      hostInfo.value = response.data;

      if (!response.data!.baseInfo.su && showErrorSu) {
        showErrorSnackbar(
          'access_denied_system_info'.tr,
          'access_denied_system_info_description'.tr,
        );
        return;
      }
    } catch (e) {
      showErrorSnackbar(
        'error_processing_data'.tr,
        'error_processing_data_description'.tr,
      );
    }
  }

  /// Method to handle the menu item selection
  void selectMenuItem(int index) {
    selectedMenuIndex.value = index;
  }

  /// Method to handle the menu item selection
  void toggleShowHostFull() {
    GetStorage(
      SettingsConst.kSettings,
    ).write(SettingsConst.kShowHostInfo, !showHostFull.value);
    showHostFull.value = !showHostFull.value;
  }

  /// Disconnect from the device
  Future<void> disconnectFromDevice() async {
    await BackgroundConnectionService.stopService();
    stopBackgroundService();
    webSocketProvider.disconnect();
    isConnected.value = false;
    Get.back(result: {'disconnectReason': true});
  }
}
