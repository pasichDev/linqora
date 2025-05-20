import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:linqoraremote/data/enums/type_messages_ws.dart';
import 'package:linqoraremote/data/models/discovered_service.dart';
import 'package:linqoraremote/data/models/host_info.dart';
import 'package:linqoraremote/data/models/ws_message.dart';
import 'package:linqoraremote/services/background_service.dart';

import '../../core/constants/settings.dart';
import '../../core/utils/error_handler.dart';
import '../../data/models/server_response.dart';
import '../../data/providers/websocket_provider.dart';

class DeviceHomeController extends GetxController with WidgetsBindingObserver {
  final WebSocketProvider webSocketProvider;

  DeviceHomeController({required this.webSocketProvider});

  final RxBool isConnected = false.obs;
  final RxInt selectedMenuIndex = (-1).obs;
  final RxBool isBackgroundServiceRunning = false.obs;
  final RxBool isReconnecting = false.obs;

  final RxMap deviceInfo = {}.obs;
  final Rxn<HostSystemInfo> hostInfo = Rxn<HostSystemInfo>();
  Timer? _serviceStatusTimer;

  final Rxn<MdnsDevice> authDevice = Rxn<MdnsDevice>();

  @override
  Future<void> onInit() async {
    super.onInit();

    // Получаем данные устройства из аргументов
    await _setupFromArguments();

    // Настраиваем обработчики WebSocket
    _setupWebSocketHandlers();

    // Запускаем таймер для проверки статуса сервиса
    _startServiceStatusCheck();

    // Настраиваем обработчики
    setupBackgroundServiceHandlers();

    // Запускаем фоновый сервис
    _startBackgroundServiceIfNeeded();
  }

  @override
  void onClose() {
    stopBackgroundService();
    _serviceStatusTimer?.cancel();

    webSocketProvider.removeHandler('media');
    webSocketProvider.removeHandler('host_info');

    BackgroundConnectionService.removeMessageHandler(
      _handleBackgroundServiceMessage,
    );

    super.onClose();
  }

  // Метод для запуска фонового сервиса
  void _startBackgroundServiceIfNeeded() async {
    if (authDevice.value != null && isConnected.value) {
      final deviceName = authDevice.value!.name;
      final deviceAddress =
          "${authDevice.value!.address}:${authDevice.value!.port}";
      final notificationsEnabled =
          GetStorage(
            SettingsConst.kSettings,
          ).read<bool>(SettingsConst.kEnableNotifications) ??
          false;

      // Запускаем фоновый сервис с текущим состоянием соединения
      await BackgroundConnectionService.startService(
        deviceName,
        deviceAddress,
        isConnected.value,
      );

      // Дополнительное обновление информации через небольшой интервал
      Future.delayed(const Duration(seconds: 3), () {
        BackgroundConnectionService.forceUpdateDeviceInfo(
          deviceName,
          deviceAddress,
          isConnected.value,
          notificationsEnabled,
        );
      });
    }
  }

  // Метод для подключения обработчиков сообщений от фонового сервиса
  void setupBackgroundServiceHandlers() {
    BackgroundConnectionService.addMessageHandler(
      _handleBackgroundServiceMessage,
    );
  }

  // Обработчик сообщений от фонового сервиса
  void _handleBackgroundServiceMessage(String message) {
    if (message == BackgroundConnectionService.MESSAGE_CHECK_CONNECTION) {
      _checkConnection();
    } else if (message == BackgroundConnectionService.MESSAGE_CONNECTION_LOST) {
      if (webSocketProvider.isConnected) {
        _checkConnection(forcePing: true);
      }
    }
  }

  // Метод для проверки соединения
  void _checkConnection({bool forcePing = false}) {
    if (!webSocketProvider.isConnected && !forcePing) {
      BackgroundConnectionService.reportConnectionState(false);
      return;
    }

    webSocketProvider.sendPing();
  }

  Future<void> _setupFromArguments() async {
    final args = Get.arguments;

    if (args != null && args['device'] != null) {
      if (args['device'] != null) {
        try {
          authDevice.value = MdnsDevice.fromJson(args['device']);
          // Save device data to storage lsat connect
          GetStorage(
            SettingsConst.kSettings,
          ).write(SettingsConst.kLastConnect, authDevice.value!.toJson());
        } catch (e) {
          if (kDebugMode) {
            print("Error parse device data: ${args['device']}");
          }
        }
      }

      isConnected.value = webSocketProvider.isConnected;
    }
  }

  void _setupWebSocketHandlers() {
    webSocketProvider.onDisconnected = () {
      isConnected.value = false;
      Get.back(result: true);
      showErrorSnackbar(
        'Соединение разорвано',
        'Соединение с устройством Linqora было прервано',
      );
    };

    webSocketProvider.registerHandler(
      TypeMessageWs.host_info.value,
      _handleSystemInfo,
    );

    _requestSystemInfo();
  }

  // Запускаем таймер проверки статуса фонового сервиса
  void _startServiceStatusCheck() {
    _serviceStatusTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      isBackgroundServiceRunning.value =
          await BackgroundConnectionService.isRunning();
    });
  }

  // Остановка фонового сервиса
  Future<void> stopBackgroundService() async {
    try {
      await BackgroundConnectionService.stopService();
      isBackgroundServiceRunning.value = false;
      if (kDebugMode) {
        print('Background service stopped');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping background service: $e');
      }
    }
  }

  // Запрос информации о системе
  void _requestSystemInfo() {
    if (!isConnected.value) return;

    try {
      webSocketProvider.sendMessage(
        WsMessage(type: TypeMessageWs.host_info.value),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error requesting system info: $e');
      }
    }
  }

  // Обработчик информации о системе
  void _handleSystemInfo(Map<String, dynamic> data) {
    try {
      final response = ServerResponse<HostSystemInfo>.fromJson(
        data,
        (json) => HostSystemInfo.fromJson(json),
      );
      if (response.hasError) {
        showErrorSnackbar(
          'Ошибка получения данных',
          'Не удалось получить информацию о системе: ${response.error?.message}',
        );
        return;
      }
      hostInfo.value = response.data;
    } catch (e) {
      showErrorSnackbar(
        'Ошибка обработки данных',
        'Не удалось обработать информацию о системе',
      );
    }
  }

  // Метод для выбора пункта меню
  void selectMenuItem(int index) {
    selectedMenuIndex.value = index;
  }

  // Отключиться от устройства
  Future<void> disconnectFromDevice() async {
    await BackgroundConnectionService.stopService();
    stopBackgroundService();
    webSocketProvider.disconnect();
    isConnected.value = false;
    Get.back(result: {'disconnectReason': true});
  }
}
