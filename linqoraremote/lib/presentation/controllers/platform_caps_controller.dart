import 'package:get/get.dart';
import 'package:linqoraremote/core/constants/settings.dart';
import 'package:linqoraremote/data/providers/websocket_provider.dart';

import '../../data/enums/type_request_host.dart';

class PlatformCapsController extends GetxController {
  final WebSocketProvider webSocketProvider;

  PlatformCapsController({required this.webSocketProvider});

  final RxString platform = ''.obs;
  final RxMap<String, bool> features = <String, bool>{}.obs;
  final RxString hostAppVersion = ''.obs;
  final RxInt hostApiVersion = 0.obs;

  /// True when the host reports an API version higher than this app supports.
  bool get isApiVersionMismatch =>
      hostApiVersion.value > 0 && hostApiVersion.value != kApiVersion;

  @override
  void onInit() {
    webSocketProvider.registerHandler(
      TypeMessageWs.platform_caps.value,
      _onPlatformCaps,
    );
    _requestCaps();
    super.onInit();
  }

  @override
  void onClose() {
    webSocketProvider.removeHandler(TypeMessageWs.platform_caps.value);
    super.onClose();
  }

  void _requestCaps() {
    if (!webSocketProvider.isReadyForCommand()) return;
    webSocketProvider.sendMessage({'type': TypeMessageWs.platform_caps.value});
  }

  void _onPlatformCaps(Map<String, dynamic> message) {
    final data = message['data'];
    if (data is! Map<String, dynamic>) return;

    platform.value = (data['platform'] as String?) ?? '';
    hostAppVersion.value = (data['app_version'] as String?) ?? '';
    hostApiVersion.value = (data['api_version'] as int?) ?? 0;

    final raw = data['features'];
    if (raw is Map<String, dynamic>) {
      features.assignAll(raw.map((k, v) => MapEntry(k, v == true)));
    }

    if (isApiVersionMismatch) {
      Get.snackbar(
        'Version mismatch',
        'Host API v${hostApiVersion.value} ≠ app API v$kApiVersion. '
            'Update the app or LinqoraHost to avoid issues.',
        duration: const Duration(seconds: 8),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  bool has(String cap) => features[cap] == true;
}
