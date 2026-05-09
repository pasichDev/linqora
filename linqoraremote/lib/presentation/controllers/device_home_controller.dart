import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
import '../../data/providers/websocket_provider.dart'
    show WebSocketProvider, ReconnectState;
import '../../services/permissions_service.dart';
import 'settings_controller.dart';

class DeviceHomeController extends GetxController with WidgetsBindingObserver {
  final WebSocketProvider webSocketProvider;

  DeviceHomeController({required this.webSocketProvider});

  final RxInt selectedMenuIndex = (-1).obs;
  final RxBool showHostFull = false.obs;
  final RxMap deviceInfo = {}.obs;
  final Rxn<HostSystemInfo> hostInfo = Rxn<HostSystemInfo>();
  final Rxn<MdnsDevice> authDevice = Rxn<MdnsDevice>();
  
  // New: Reactive AppBar management
  final RxList<Widget> appBarActions = <Widget>[].obs;
  final RxnString appBarTitleOverride = RxnString();
  final Rxn<VoidCallback> onBackPressed = Rxn<VoidCallback>();

  DateTime _refreshLastTime = DateTime.now();

  @override
  Future<void> onInit() async {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);

    /// Get the device information from the arguments
    await _setupFromArguments();

    /// Load the settings
    _loadingSettings();

    /// Set up the WebSocket handlers
    _setupWebSocketHandlers();

    /// Set up the background service handlers
    setupBackgroundServiceHandlers();

    /// Start the background service if needed
    _startBackgroundServiceIfNeeded();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    webSocketProvider.removeHandler(TypeMessageWs.host_info.value);
    webSocketProvider.removeHandler(TypeMessageWs.battery_alert.value);
    BackgroundConnectionService.removeMessageHandler(
      _handleBackgroundServiceMessage,
    );
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        webSocketProvider.reconnectState.value == ReconnectState.failed) {
      webSocketProvider.retryReconnect();
    }
  }

  /// Get settings from storage
  void _loadingSettings() {
    try {
      showHostFull.value =
          GetStorage(
            SettingsConst.kSettings,
          ).read<bool>(SettingsConst.kShowHostInfo) ??
          false;
    } catch (e) {
      AppLogger.release(
        'Error loading settings: $e',
        module: "DeviceHomeController",
      );
    }
  }

  /// Start the background service if needed
  void _startBackgroundServiceIfNeeded() async {
    if (authDevice.value != null && webSocketProvider.isConnected) {
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
        webSocketProvider.isConnected,
      );

      /// Force update device info
      Future.delayed(const Duration(seconds: 3), () {
        BackgroundConnectionService.forceUpdateDeviceInfo(
          deviceName,
          deviceAddress,
          webSocketProvider.isConnected,
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
      if (webSocketProvider.isConnected) {
        webSocketProvider.sendPing();
        return;
      }
      disconnectFromDevice(isCleaned: true, servicePause: true);
    } else if (message == BackgroundConnectionService.MESSAGE_CONNECTION_LOST) {
      if (webSocketProvider.isConnected) {
        webSocketProvider.sendPing();
        showErrorSnackbar(
          'connection_unstable_title'.tr,
          'connection_unstable_message'.tr,
        );
        return;
      }

      disconnectFromDevice(isCleaned: true, servicePause: true);
    }
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
          try {
            Get.find<SettingsController>().addSavedHost(authDevice.value!);
          } catch (_) {}
        } catch (e) {
          AppLogger.release(
            'Error parse device data: ${args['device']}',
            module: "DeviceHomeController",
          );
        }
      }
    }
  }

  /// Method to set up WebSocket handlers
  void _setupWebSocketHandlers() {
    webSocketProvider.onDisconnectedChanger = (disconnected) {
      if (disconnected) {
        showErrorSnackbar(
          'connection_broken'.tr,
          'connection_broken_description'.tr,
        );
        disconnectFromDevice(servicePause: true);
      }
    };

    webSocketProvider.registerHandler(
      TypeMessageWs.host_info.value,
      _handleSystemInfo,
    );

    webSocketProvider.registerHandler(
      TypeMessageWs.battery_alert.value,
      _handleBatteryAlert,
    );

    _requestSystemInfo();
  }

  /// Method to refresh the host information
  void refreshHostInfo() {
    bool difference =
        DateTime.now().difference(_refreshLastTime).inSeconds >= 30;
    if (webSocketProvider.isConnected && difference) {
      _requestSystemInfo();
    }
  }

  /// Request system information
  void _requestSystemInfo() {
    if (!webSocketProvider.isConnected) return;
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
    appBarActions.clear();
    appBarTitleOverride.value = null;
    onBackPressed.value = null;
  }

  /// Method to handle the menu item selection
  void toggleShowHostFull() {
    GetStorage(
      SettingsConst.kSettings,
    ).write(SettingsConst.kShowHostInfo, !showHostFull.value);
    showHostFull.value = !showHostFull.value;
  }

  void _handleBatteryAlert(Map<String, dynamic> data) {
    try {
      final settingsCtrl = Get.find<SettingsController>();
      if (!settingsCtrl.enableNotifications.value) return;
      final payload = data['data'] as Map<String, dynamic>?;
      final percent = (payload?['percent'] as num?)?.toInt() ?? 0;
      _showBatteryNotification(percent);
    } catch (e) {
      AppLogger.release('Battery alert error: $e', module: 'DeviceHomeController');
    }
  }

  Future<void> _showBatteryNotification(int percent) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return;
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      const channel = AndroidNotificationChannel(
        'linqora_battery',
        'Battery Alerts',
        description: 'Low battery alerts from the host computer',
        importance: Importance.high,
      );
      await plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
      await plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      await plugin.show(
        42,
        'Host Battery Low',
        'Battery is at $percent% — consider plugging in.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'linqora_battery',
            'Battery Alerts',
            channelDescription: 'Low battery alerts from the host computer',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      AppLogger.release('Notification error: $e', module: 'DeviceHomeController');
    }
  }

  /// Disconnect from the device
  Future<void> disconnectFromDevice({
    bool isCleaned = false,
    bool servicePause = false,
  }) async {
    await BackgroundConnectionService.stopService(isPause: servicePause);

    if (isCleaned) {
      webSocketProvider.disconnect(clearHandlers: true);
    }
    Get.back();

    AppLogger.release(
      'Close DeviceHomeController',
      module: "DeviceHomeController",
    );
  }
}
