import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/data/providers/websocket_provider.dart';
import 'package:linqoraremote/presentation/widgets/banner.dart';
import 'package:linqoraremote/presentation/widgets/loading_view.dart';
import 'package:linqoraremote/presentation/widgets/shimmer_effect.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:linqoraremote/core/themes/lin_styles.dart';

import '../../data/media_commands.dart';
import '../controllers/media_controller.dart';

class MediaScreenView extends StatefulWidget {
  const MediaScreenView({super.key});

  @override
  State<MediaScreenView> createState() => _MediaScreenViewState();
}

class _MediaScreenViewState extends State<MediaScreenView> {
  late final MediaController _mediaController;

  @override
  void initState() {
    super.initState();
    _mediaController = Get.put(
      MediaController(webSocketProvider: Get.find<WebSocketProvider>()),
    );
  }

  @override
  void dispose() {
    if (_isControllerRegistered<MediaController>()) {
      Get.delete<MediaController>();
    }
    super.dispose();
  }

  bool _isControllerRegistered<T>() {
    return Get.isRegistered<T>();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Obx(() {
        if (_mediaController.capabilities.value == null) {
          return const LoadingView();
        } else {
          return Column(
            children: [
              if (!_mediaController.capabilities.value!.isControlledByRemote || _mediaController.nowPlaying.value == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: MessageBanner(
                    message: _mediaController.nowPlaying.value == null ? 'info_no_playing_remote'.tr : "error_control_remote".tr,
                    isLoading: false,
                  ),
                ),
              _volumeCard(),
              const SizedBox(height: 20),
              if (_mediaController.capabilities.value!.isControlledByRemote && _mediaController.nowPlaying.value != null) _mediaCard(),
            ],
          );
        }
      }),
    );
  }

  Widget _volumeCard() {
    return LinStyles.glassMorphism(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.volume_up_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'control_sound'.tr.toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Obx(
                  () => IconButton(
                    icon: Icon(
                      _mediaController.isMuted.value ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      size: 28,
                      color: _mediaController.isMuted.value ? Colors.redAccent : Colors.white,
                    ),
                    onPressed: _mediaController.setMuted,
                  ),
                ),
                Expanded(
                  child: Obx(
                    () => SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 8,
                        activeTrackColor: Theme.of(context).colorScheme.primary,
                        inactiveTrackColor: Colors.white.withOpacity(0.1),
                        thumbColor: Colors.white,
                        overlayColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 5),
                      ),
                      child: Slider(
                        value: _mediaController.volume.value,
                        min: 0,
                        max: 100,
                        onChanged: (newValue) {
                          _mediaController.volume.value = newValue;
                        },
                        onChangeEnd: (newValue) {
                          _mediaController.slideVolume(newValue);
                        },
                      ),
                    ),
                  ),
                ),
                Obx(
                  () => SizedBox(
                    width: 45,
                    child: Text(
                      '${_mediaController.volume.value.toInt()}%',
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildVolumePresetButton('10%', 10),
                _buildVolumePresetButton('30%', 30),
                _buildVolumePresetButton('50%', 50),
                _buildVolumePresetButton('70%', 70),
                _buildVolumePresetButton('100%', 100),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mediaCard() {
    return LinStyles.glassMorphism(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Obx(() {
          if (!_mediaController.capabilities.value!.canControlMedia) {
            return Center(
              child: Text(
                'error_control_remote'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.music_note_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'now_playing'.tr.toUpperCase(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  Obx(
                    () => !_mediaController.isLoadingMedia.value
                        ? Icon(
                            _mediaController.nowPlaying.value?.isPlaying ?? false ? Icons.graphic_eq_rounded : Icons.pause_rounded,
                            color: _mediaController.nowPlaying.value?.isPlaying ?? false ? Colors.greenAccent : Colors.white24,
                            size: 20,
                          )
                        : LoadingAnimationWidget.staggeredDotsWave(
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_mediaController.capabilities.value!.canGetMediaInfo) ...[
                _buildMediaInfoSection(),
                Obx(
                  () => _buildPlaybackControls(
                    !_mediaController.isLoadingMedia.value,
                  ),
                ),
              ],
            ],
          );
        }),
      ),
    );
  }

  Widget _buildVolumePresetButton(String label, int volumeValue) {
    return InkWell(
      onTap: () => _mediaController.setVolume(volumeValue),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white70),
        ),
      ),
    );
  }

  Widget _buildMediaInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Obx(
          () => _mediaController.isLoadingMedia.value
              ? const ShimmerEffect(height: 24, width: 200)
              : Text(
                  _mediaController.nowPlaying.value!.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
        const SizedBox(height: 8),
        Obx(
          () => _mediaController.isLoadingMedia.value
              ? const ShimmerEffect(height: 16, width: 140)
              : Text(
                  _mediaController.nowPlaying.value!.artist,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.5),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
        const SizedBox(height: 32),
        Obx(() {
          final nowPlaying = _mediaController.nowPlaying.value!;
          if (nowPlaying.duration > 0 && !_mediaController.isLoadingMedia.value) {
            return Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: nowPlaying.progress.toDouble(),
                    backgroundColor: Colors.white.withOpacity(0.05),
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      nowPlaying.stringPosition.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                    Text(
                      nowPlaying.stringDuration.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ],
            );
          } else {
            return const SizedBox.shrink();
          }
        }),
      ],
    );
  }

  Widget _buildPlaybackControls(bool isEnabled) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isEnabled ? Colors.white : Colors.white24;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.skip_previous_rounded, size: 40, color: color),
          onPressed: isEnabled ? () => _mediaController.sendMediaCommand(MediaActions.mediaPrevious) : null,
        ),
        const SizedBox(width: 24),
        Obx(
          () => Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary.withOpacity(0.2),
              border: Border.all(color: colorScheme.primary.withOpacity(0.5), width: 2),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                _mediaController.nowPlaying.value!.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 48,
                color: isEnabled ? colorScheme.primary : Colors.white24,
              ),
              onPressed: isEnabled ? () => _mediaController.sendMediaCommand(MediaActions.mediaPlayPause) : null,
            ),
          ),
        ),
        const SizedBox(width: 24),
        IconButton(
          icon: Icon(Icons.skip_next_rounded, size: 40, color: color),
          onPressed: isEnabled ? () => _mediaController.sendMediaCommand(MediaActions.mediaNext) : null,
        ),
      ],
    );
  }
}
