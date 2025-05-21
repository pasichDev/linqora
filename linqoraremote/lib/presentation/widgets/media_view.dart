import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/data/providers/websocket_provider.dart';
import 'package:linqoraremote/presentation/widgets/banner.dart';
import 'package:linqoraremote/presentation/widgets/loading_view.dart';
import 'package:linqoraremote/presentation/widgets/shimmer_effect.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: Obx(() {
              if (_mediaController.capabilities.value == null) {
                return LoadingView();
              } else {
                return Column(
                  children: [
                    if (!_mediaController
                            .capabilities
                            .value!
                            .isControlledByRemote ||
                        _mediaController.nowPlaying.value == null)
                      MessageBanner(
                        message:
                            _mediaController.nowPlaying.value == null
                                ? 'info_no_playing_remote'.tr
                                : "error_control_remote".tr,
                        isLoading: false,
                      ),
                    _volumeCard(),
                    const SizedBox(height: 20),
                    if (_mediaController
                            .capabilities
                            .value!
                            .isControlledByRemote &&
                        _mediaController.nowPlaying.value != null)
                      _mediaCard(),
                  ],
                );
              }
            }),
          ),
        ],
      ),
    );
  }

  Widget _volumeCard() {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer,

      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'control_sound'.tr,
              style: Get.theme.textTheme.titleMedium?.copyWith(
                color: Get.theme.colorScheme.onPrimaryContainer,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Obx(
                  () => IconButton(
                    icon: Icon(
                      _mediaController.isMuted.value
                          ? Icons.volume_off
                          : Icons.volume_up,
                      size: 24,
                    ),
                    onPressed: _mediaController.setMuted,
                  ),
                ),
                const SizedBox(width: 5),

                IconButton(
                  icon: const Icon(Icons.remove, size: 24),
                  onPressed: _mediaController.minusVolume,
                ),

                Expanded(
                  child: Obx(
                    () => Slider(
                      value: _mediaController.volume.value,
                      min: 0,
                      max: 100,
                      divisions: 20,
                      label: '${_mediaController.volume.value.toInt()}%',
                      onChanged: (newValue) {
                        _mediaController.volume.value = newValue;
                      },
                      onChangeEnd: (newValue) {
                        _mediaController.slideVolume(newValue);
                      },
                    ),
                  ),
                ),

                IconButton(
                  icon: const Icon(Icons.add, size: 24),
                  onPressed: _mediaController.plusVolume,
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
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
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer,

      child: Padding(
        padding: const EdgeInsets.all(16),
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
                  Text(
                    'now_playing'.tr,
                    style: Get.theme.textTheme.titleMedium?.copyWith(
                      color: Get.theme.colorScheme.onPrimaryContainer,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  Obx(
                    () =>
                        !_mediaController.isLoadingMedia.value
                            ? Icon(
                              _mediaController.nowPlaying.value?.isPlaying ??
                                      false
                                  ? Icons.music_note
                                  : Icons.music_off,
                              color:
                                  _mediaController
                                              .nowPlaying
                                              .value
                                              ?.isPlaying ??
                                          false
                                      ? Colors.green
                                      : Colors.grey,
                            )
                            : LoadingAnimationWidget.fourRotatingDots(
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: 22,
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
    return TextButton(
      onPressed: () => _mediaController.setVolume(volumeValue),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        minimumSize: const Size(0, 0),
      ),
      child: Text(
        label,
        style: Get.theme.textTheme.labelLarge?.copyWith(
          color: Get.theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  Widget _buildMediaInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Obx(
          () =>
              _mediaController.isLoadingMedia.value
                  ? ShimmerEffect(height: 16, width: 160)
                  : Text(
                    "${_mediaController.nowPlaying.value!.title} - ${_mediaController.nowPlaying.value!.artist}",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
        ),
        Obx(
          () =>
              _mediaController.isLoadingMedia.value
                  ? SizedBox(height: 5)
                  : SizedBox(),
        ),

        Obx(() {
          final app = _mediaController.nowPlaying.value!.application;
          if (!_mediaController.isLoadingMedia.value) {
            return Text(
              app.isEmpty ? 'unknown_app'.tr : app,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            );
          } else {
            return ShimmerEffect(height: 12, width: 110);
          }
        }),

        const SizedBox(height: 20),
        Obx(() {
          if (_mediaController.nowPlaying.value!.duration > 0 &&
              !_mediaController.isLoadingMedia.value) {
            return Column(
              children: [
                LinearProgressIndicator(
                  value: _mediaController.nowPlaying.value!.progress.toDouble(),
                  backgroundColor: Colors.grey.shade300.withAlpha(60),
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _mediaController.nowPlaying.value!.stringPosition
                          .toString(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),

                    Text(
                      _mediaController.nowPlaying.value!.stringDuration
                          .toString(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
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

        const SizedBox(height: 5),
      ],
    );
  }

  Widget _buildPlaybackControls(bool isEnabled) {
    var color =
        isEnabled
            ? Theme.of(context).colorScheme.onSurface.withAlpha(1000)
            : Theme.of(context).colorScheme.onSurface.withAlpha(100);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.skip_previous, size: 36, color: color),
          onPressed: () {
            if (isEnabled) {
              _mediaController.sendMediaCommand(MediaActions.mediaPrevious);
            }
          },
        ),

        const SizedBox(width: 16),

        Obx(
          () => IconButton(
            icon: Icon(
              _mediaController.nowPlaying.value!.isPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_filled,
              size: 48,
              color: color,
            ),
            onPressed: () {
              if (isEnabled) {
                _mediaController.sendMediaCommand(MediaActions.mediaPlayPause);
              }
            },
          ),
        ),

        const SizedBox(width: 16),

        IconButton(
          icon: Icon(Icons.skip_next, size: 36, color: color),
          onPressed: () {
            if (isEnabled) {
              _mediaController.sendMediaCommand(MediaActions.mediaNext);
            }
          },
        ),
      ],
    );
  }
}
