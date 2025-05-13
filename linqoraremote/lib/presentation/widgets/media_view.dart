import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
  late final MediaController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.find<MediaController>();
    controller.joinRoom();
  }

  @override
  void dispose() {
    controller.leaveRoom();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: Obx(() {
              if (controller.nowPlaying.value == null ||
                  controller.capabilities.value == null) {
                return LoadingView();
              } else {
                return Column(
                  children: [
                    _volumeCard(),
                    const SizedBox(height: 20),
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
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Керування звуком',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                // Кнопка выключения звука
                Obx(
                  () => IconButton(
                    icon: Icon(
                      controller.isMuted.value
                          ? Icons.volume_off
                          : Icons.volume_up,
                      size: 24,
                    ),
                    onPressed: controller.setMuted,
                  ),
                ),
                const SizedBox(width: 5),

                // Кнопка уменьшения громкости
                IconButton(
                  icon: const Icon(Icons.remove, size: 24),
                  onPressed: controller.minusVolume,
                ),

                // Слайдер громкости
                Expanded(
                  child: Obx(
                    () => Slider(
                      value: controller.volume.value,
                      min: 0,
                      max: 100,
                      divisions: 20,
                      label: '${controller.volume.value.toInt()}%',
                      onChanged: (newValue) {
                        controller.volume.value = newValue;
                      },
                      onChangeEnd: (newValue) {
                        controller.slideVolume(newValue);
                      },
                    ),
                  ),
                ),

                // Кнопка увеличения громкости
                IconButton(
                  icon: const Icon(Icons.add, size: 24),
                  onPressed: controller.plusVolume,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Предустановленные уровни громкости
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
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          if (!controller.capabilities.value!.canControlMedia) {
            return const Center(
              child: Text(
                'Управление мультимедиа недоступно на устройстве',
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
                  const Text(
                    'Зараз грає',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  // Индикатор обновления в реальном времени
                  Obx(
                    () =>
                        !controller.isLoadingMedia.value
                            ? Icon(
                              controller.nowPlaying.value?.isPlaying ?? false
                                  ? Icons.music_note
                                  : Icons.music_off,
                              color:
                                  controller.nowPlaying.value?.isPlaying ??
                                          false
                                      ? Colors.green
                                      : Colors.grey,
                            )
                            : LoadingAnimationWidget.fourRotatingDots(
                              color: Theme.of(context).colorScheme.onSurface,
                              size: 22,
                            ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (controller.capabilities.value!.canGetMediaInfo) ...[
                _buildMediaInfoSection(),
                Obx(
                  () =>
                      _buildPlaybackControls(!controller.isLoadingMedia.value),
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
      onPressed: () => controller.setVolume(volumeValue),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        minimumSize: const Size(0, 0),
      ),
      child: Text(label, style: const TextStyle(fontSize: 14)),
    );
  }

  // Секция с информацией о текущем треке
  Widget _buildMediaInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Obx(
          () =>
              controller.isLoadingMedia.value
                  ? ShimmerEffect(height: 16, width: 160)
                  : Text(
                    "${controller.nowPlaying.value!.title} - ${controller.nowPlaying.value!.artist}",
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
              controller.isLoadingMedia.value
                  ? SizedBox(height: 5)
                  : SizedBox(),
        ),

        Obx(() {
          final app = controller.nowPlaying.value!.application;
          if (!controller.isLoadingMedia.value) {
            return Text(
              app.isEmpty ? 'Неизвестное приложение' : app,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            );
          } else {
            return ShimmerEffect(height: 12, width: 110);
          }
        }),

        // Прогресс воспроизведения
        const SizedBox(height: 20),
        Obx(() {
          if (controller.nowPlaying.value!.duration > 0 &&
              !controller.isLoadingMedia.value) {
            return Column(
              children: [
                LinearProgressIndicator(
                  value: controller.nowPlaying.value!.progress.toDouble(),
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
                      controller.nowPlaying.value!.stringPosition.toString(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),

                    Text(
                      controller.nowPlaying.value!.stringDuration.toString(),
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

  // Кнопки управления воспроизведением
  Widget _buildPlaybackControls(bool isEnabled) {
    var color =
        isEnabled
            ? Theme.of(context).colorScheme.onSurface.withAlpha(1000)
            : Theme.of(context).colorScheme.onSurface.withAlpha(100);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Предыдущий трек
        IconButton(
          icon: Icon(Icons.skip_previous, size: 36, color: color),
          onPressed: () {
            if (isEnabled) {
              controller.sendMediaCommand(MediaActions.mediaPrevious);
            }
          },
        ),

        const SizedBox(width: 16),

        // Воспроизведение/Пауза
        Obx(
          () => IconButton(
            icon: Icon(
              controller.nowPlaying.value!.isPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_filled,
              size: 48,
              color: color,
            ),
            onPressed: () {
              if (isEnabled) {
                controller.sendMediaCommand(MediaActions.mediaPlayPause);
              }
            },
          ),
        ),

        const SizedBox(width: 16),

        // Следующий трек
        IconButton(
          icon: Icon(Icons.skip_next, size: 36, color: color),
          onPressed: () {
            if (isEnabled) {
              controller.sendMediaCommand(MediaActions.mediaNext);
            }
          },
        ),
      ],
    );
  }
}
