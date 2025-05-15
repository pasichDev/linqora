import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/data/enums/type_messages_ws.dart';
import 'package:linqoraremote/data/models/discovered_service.dart';
import 'package:linqoraremote/data/models/host_system_info.dart';
import 'package:linqoraremote/data/models/ws_message.dart';

import '../../data/providers/websocket_provider.dart';
import '../../routes/app_routes.dart';

class DeviceHomeController extends GetxController {
  final WebSocketProvider webSocketProvider;

  DeviceHomeController({required this.webSocketProvider});

  final RxBool isConnected = false.obs;
  final RxInt selectedMenuIndex = (-1).obs;

  final RxMap deviceInfo = {}.obs;
  final Rxn<HostSystemInfo> hostInfo = Rxn<HostSystemInfo>();
  Timer? _connectionCheckTimer;

  final Rxn<DiscoveredService> authDevice = Rxn<DiscoveredService>();

  @override
  void onInit() {
    super.onInit();

    // Получаем данные устройства из аргументов
    _setupFromArguments();

    // Настраиваем обработчики WebSocket
    _setupWebSocketHandlers();

    // Запускаем таймер для проверки соединения
    _startConnectionCheck();
  }

  void _setupFromArguments() {
    final args = Get.arguments;

    if (args != null && args['device'] != null) {
      if (args['device'] != null) {
        try {
          authDevice.value = DiscoveredService.fromJson(args['device']);
        } catch (e) {
          if (kDebugMode) {
            print("Device data: ${args['device']}");
          }
        }
      }

      isConnected.value = webSocketProvider.isConnected;

      if (!isConnected.value) {
        if (kDebugMode) {
          print("WebSocket connection is not established");
        }

        // Более надежная обработка перехода назад
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Get.back();
          Get.snackbar(
            'Ошибка соединения',
            'Соединение с устройством потеряно',
            snackPosition: SnackPosition.BOTTOM,
          );
        });
      }
    }
  }

  void _setupWebSocketHandlers() {
    webSocketProvider.onDisconnected = () {
      isConnected.value = false;
      Get.offAllNamed(AppRoutes.DEVICE_AUTH);
      Get.snackbar(
        'Соединение разорвано',
        'Соединение с устройством Linqora было прервано',
        snackPosition: SnackPosition.BOTTOM,
      );
    };
    webSocketProvider.registerHandler(
      TypeMessageWs.host_info.value,
      _handleSystemInfo,
    );
    _requestSystemInfo();
  }

  // Запрос информации о системе
  void _requestSystemInfo() {
    if (!isConnected.value) return;

    try {
      final message = {'type': 'host_info', 'data': {}};

      webSocketProvider.sendJson(message);
    } catch (e) {
      if (kDebugMode) {
        print('Error requesting system info: $e');
      }
    }
  }

  // Обработчик информации о системе
  void _handleSystemInfo(Map<String, dynamic> data) {
    try {
      if (kDebugMode) {
        print('Received system info: $data');
      }
      final newHostInfo = HostSystemInfo.fromJson(data['host_info']);
      hostInfo.value = newHostInfo;
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing system info: $e');
      }
      Get.snackbar(
        'Ошибка обработки данных',
        'Не удалось обработать информацию о системе',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // Запуск таймера для проверки состояния соединения
  void _startConnectionCheck() {
    _connectionCheckTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      if (kDebugMode) {
        print(webSocketProvider.isConnected);
      }
      if (!webSocketProvider.isConnected) {
        isConnected.value = false;
        timer.cancel();

        Get.offAllNamed(AppRoutes.DEVICE_AUTH);
        Get.snackbar(
          'Соединение потеряно',
          'Соединение с устройством было прервано',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    });
  }

  // Метод для выбора пункта меню
  void selectMenuItem(int index) {
    selectedMenuIndex.value = index;
  }

  // Отключиться от устройства
  void disconnectFromDevice() {
    webSocketProvider.disconnect();
    isConnected.value = false;
    Get.back(result: {'disconnectReason': true});
  }

  @override
  void onClose() {
    _connectionCheckTimer?.cancel();
    webSocketProvider.removeHandler('media');
    webSocketProvider.removeHandler('system_info');
    super.onClose();
  }
}
