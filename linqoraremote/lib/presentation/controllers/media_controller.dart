import 'dart:async';

import 'package:get/get.dart';
import 'package:linqoraremote/data/media_commands.dart';
import 'package:linqoraremote/data/providers/websocket_provider.dart';

import '../../core/utils/error_handler.dart';
import '../../core/utils/formatter.dart';
import '../../data/enums/type_messages_ws.dart';
import '../../data/models/media_capabilities.dart';
import '../../data/models/now_playing.dart';

class MediaController extends GetxController {
  final WebSocketProvider webSocketProvider;

  MediaController({required this.webSocketProvider});

  final RxDouble volume = 50.0.obs;
  final RxBool isMuted = false.obs;

  final Rxn<MediaCapabilities> capabilities = Rxn<MediaCapabilities>();
  final Rxn<NowPlaying> nowPlaying = Rxn<NowPlaying>();

  final RxBool isLoadingMedia = false.obs;

  @override
  void onInit() {
    _init();
    super.onInit();
  }

  @override
  void onClose() {
    webSocketProvider.leaveRoom(TypeMessageWs.media.value);
    webSocketProvider.removeHandler(TypeMessageWs.media.value);

    capabilities.value = null;
    nowPlaying.value = null;
    super.onClose();
  }

  Future<void> _init() async {
    webSocketProvider.registerHandler(
      TypeMessageWs.media.value,
      _handleMediaData,
    );

    await webSocketProvider.joinRoom(TypeMessageWs.media.value);
  }

  void _handleMediaData(dynamic data) {
    final mediaData = data['data'];
    if (mediaData != null && mediaData is Map<String, dynamic>) {
      _handleNowPlayingData(mediaData);
      _handleCapabilitiesData(mediaData);

      if (isLoadingMedia.value) {
        isLoadingMedia.value = false;
      }
    }
  }

  void _handleNowPlayingData(Map<String, dynamic> mediaData) {
    final nowPlayingData = mediaData['nowPlaying'] as Map<String, dynamic>?;
    if (nowPlayingData != null) {
      nowPlaying.value = NowPlaying.fromJson(nowPlayingData).copyWith(
        stringDuration: formatTimeTrack(nowPlayingData['duration'] as int),
        stringPosition: formatTimeTrack(nowPlayingData['position'] as int),
      );
    }
  }

  void _handleCapabilitiesData(Map<String, dynamic> mediaData) {
    final capabilitiesData =
        mediaData['mediaCapabilities'] as Map<String, dynamic>?;
    if (capabilitiesData != null) {
      capabilities.value = MediaCapabilities.fromJson(capabilitiesData);
      volume.value = double.parse(capabilities.value!.currentVolume.toString());
      isMuted.value = capabilities.value!.isMuted;
    }
  }

  Future<void> sendMediaCommand(int action, {int value = 0}) async {
    await _sendMediaCommand(action, value);

    final current = nowPlaying.value;
    if (current == null) return;

    if (action == MediaActions.mediaPlayPause) {
      nowPlaying.value = current.copyWith(isPlaying: !current.isPlaying);
    }
    if (action == MediaActions.mediaNext ||
        action == MediaActions.mediaPrevious) {
      isLoadingMedia.value = true;
    }
  }

  Future<void> minusVolume() async {
    if (volume.value > 0) {
      volume.value = (volume.value - 5).clamp(0, 100);
      await sendMediaCommand(
        AudioActions.setVolume,
        value: volume.value.toInt(),
      );
    } else {
      await sendMediaCommand(AudioActions.decreaseVolume, value: 0);
    }
  }

  Future<void> plusVolume() async {
    if (volume.value < 100) {
      volume.value = (volume.value + 5).clamp(0, 100);
      await sendMediaCommand(
        AudioActions.setVolume,
        value: volume.value.toInt(),
      );
      if (isMuted.value) {
        isMuted.value = false;
        await sendMediaCommand(AudioActions.mute, value: 0);
      }
    } else {
      await sendMediaCommand(AudioActions.increaseVolume, value: 0);
    }
  }

  Future<void> slideVolume(double newValue) async {
    volume.value = newValue.clamp(0, 100);
    await sendMediaCommand(AudioActions.setVolume, value: volume.value.toInt());
    if (isMuted.value && volume.value > 0) {
      isMuted.value = false;
      await sendMediaCommand(AudioActions.mute, value: 0);
    }
  }

  Future<void> setVolume(int newValue) async {
    volume.value = newValue.toDouble().clamp(0, 100);
    await sendMediaCommand(AudioActions.setVolume, value: newValue);
    if (isMuted.value && newValue > 0) {
      isMuted.value = false;
      await sendMediaCommand(AudioActions.mute, value: 0);
    }
  }

  Future<void> setMuted() async {
    isMuted.value = !isMuted.value;
    await sendMediaCommand(AudioActions.mute, value: isMuted.value ? 1 : 0);
  }

  // Отправить команду управления мультимедиа
  Future<bool> _sendMediaCommand(int action, int value) async {
    if (!webSocketProvider.isReadyForCommand() ||
        !await webSocketProvider.isJoinedRoom(TypeMessageWs.media.value)) {
      showErrorSnackbar(
        'Помилка відправки медіа команди:',
        'Операція не може бути виконана: клієнт не підключений або не авторизований',
      );
      return false;
    }

    try {
      final message = {
        'type': TypeMessageWs.media.value,
        'room': TypeMessageWs.media.value,
        'data': {'action': action, 'value': value},
      };

      webSocketProvider.sendMessage(message);
      return true;
    } catch (e) {
      showErrorSnackbar('Помилка відправки медіа команди:', e.toString());
      return false;
    }
  }
}
