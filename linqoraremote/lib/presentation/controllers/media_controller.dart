import 'dart:async';

import 'package:get/get.dart';
import 'package:linqoraremote/data/media_commands.dart';
import 'package:linqoraremote/data/providers/websocket_provider.dart';

import '../../data/enums/type_messages_ws.dart';
import '../../data/models/media_capabilities.dart';
import '../../data/models/now_playing.dart';
import '../../utils/formatter.dart';

class MediaController extends GetxController {
  final WebSocketProvider webSocketProvider;

  MediaController({required this.webSocketProvider});

  final RxDouble volume = 50.0.obs;
  final RxBool isMuted = false.obs;

  final Rxn<MediaCapabilities> capabilities = Rxn<MediaCapabilities>();
  final Rxn<NowPlaying> nowPlaying = Rxn<NowPlaying>();

  final RxBool isLoadingMedia = false.obs;

  @override
  void onClose() {
    leaveRoom();
    super.onClose();
  }

  Future<void> joinRoom() async {
    webSocketProvider.registerHandler(TypeMessageWs.media.value, (data) {
      final mediaData = data['data'];
      if (mediaData != null && mediaData is Map<String, dynamic>) {
        final nowPlayingData = mediaData['nowPlaying'] as Map<String, dynamic>?;

        if (nowPlayingData != null) {
          nowPlaying.value = NowPlaying.fromJson(nowPlayingData).copyWith(
            stringDuration: formatTimeTrack(nowPlayingData['duration'] as int),
            stringPosition: formatTimeTrack(nowPlayingData['position'] as int),
          );
        }

        final capabilitiesData =
            mediaData['mediaCapabilities'] as Map<String, dynamic>?;
        if (capabilitiesData != null) {
          capabilities.value = MediaCapabilities.fromJson(capabilitiesData);
        }
        if (isLoadingMedia.value) {
          isLoadingMedia.value = false;
        }
      }
    });

    await webSocketProvider.joinRoom(TypeMessageWs.media.value);
  }

  void leaveRoom() {
    webSocketProvider.leaveRoom(TypeMessageWs.media.value);
    webSocketProvider.removeHandler(TypeMessageWs.media.value);

    capabilities.value = null;
    nowPlaying.value = null;
  }

  Future<void> sendMediaCommand(int action, {int value = 0}) async {
    await webSocketProvider.sendMediaCommand(action, value);

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
}
