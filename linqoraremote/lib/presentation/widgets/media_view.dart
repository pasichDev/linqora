import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/data/providers/websocket_provider.dart';
import 'package:linqoraremote/core/themes/lx_theme.dart';
import 'package:linqoraremote/presentation/widgets/lx_glass.dart';
import 'package:linqoraremote/presentation/widgets/lx_header.dart';
import 'package:linqoraremote/presentation/controllers/device_home_controller.dart';

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
    return Obx(() {
      final caps = _mediaController.capabilities.value;
      if (caps == null) return _loading();

      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        child: Column(
          children: [
            _header(),
            const SizedBox(height: 6),
            _albumArt(),
            const SizedBox(height: 22),
            _trackInfo(),
            const SizedBox(height: 22),
            if (caps.isControlledByRemote &&
                _mediaController.nowPlaying.value != null) ...[
              _scrubber(),
              const SizedBox(height: 22),
              _transport(),
            ],
            const SizedBox(height: 22),
            _volumeRow(context),
            const SizedBox(height: 10),
            _outputRow(),
          ],
        ),
      );
    });
  }

  Widget _loading() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(60),
        child: CircularProgressIndicator(color: lxAccent, strokeWidth: 2),
      ),
    );
  }

  Widget _header() {
    final hostname =
        Get.find<DeviceHomeController>().hostInfo.value?.hostname ?? 'Device';
    final app = _mediaController.nowPlaying.value?.application ?? '';
    final eyebrow = app.isNotEmpty ? '$app · $hostname' : hostname;
    return LxHeader(
      title: 'Now Playing',
      eyebrow: eyebrow,
      showBack: false,
      action: LxGlass(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: const Icon(
              Icons.more_horiz_rounded,
              size: 16,
              color: lxTextDim,
            ),
          ),
        ),
      ),
    );
  }

  Widget _albumArt() {
    return Center(
      child: Container(
        width: 240,
        height: 240,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: lxHairline),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2600E5FF),
              blurRadius: 60,
              offset: Offset(0, 30),
            ),
            BoxShadow(
              color: Color(0x80000000),
              blurRadius: 30,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Base gradient — cyan blob top-left
              Container(
                decoration: const BoxDecoration(
                  color: lxSurface,
                  gradient: RadialGradient(
                    center: Alignment(-0.6, -0.4),
                    radius: 0.8,
                    colors: [Color(0x8C00E5FF), Color(0x007C9CFF)],
                  ),
                ),
              ),
              // Lavender blob bottom-right
              Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.6, 0.4),
                    radius: 0.9,
                    colors: [Color(0x807C9CFF), Color(0x007C9CFF)],
                  ),
                ),
              ),
              // Soft red blob top-right
              Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.2, -0.6),
                    radius: 0.7,
                    colors: [Color(0x59FF4D5E), Color(0x00FF4D5E)],
                  ),
                ),
              ),
              // Scanline texture
              Opacity(
                opacity: 0.08,
                child: CustomPaint(painter: _ScanlinePainter()),
              ),
              // "SIDE A" micro-label
              const Positioned(
                bottom: 14,
                left: 14,
                child: Text(
                  'SIDE A · 2024',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xB3FFFFFF),
                    letterSpacing: 2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trackInfo() {
    return Obx(() {
      final np = _mediaController.nowPlaying.value;
      return Column(
        children: [
          Text(
            np?.title ?? 'Nothing playing',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: lxText,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            np != null
                ? '${np.artist}${np.album.isNotEmpty ? ' · ${np.album}' : ''}'
                : '',
            style: const TextStyle(fontSize: 13, color: lxTextDim),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    });
  }

  Widget _scrubber() {
    return Obx(() {
      final np = _mediaController.nowPlaying.value;
      final progress = (np?.progress ?? 0.0).toDouble();
      return Column(
        children: [
          LayoutBuilder(
            builder: (ctx, c) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: lxHairline,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: lxAccent,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: const [
                          BoxShadow(color: Color(0x8800E5FF), blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: (c.maxWidth * progress - 6).clamp(
                      0,
                      c.maxWidth - 12,
                    ),
                    top: -4,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: lxText,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x2E00E5FF),
                            spreadRadius: 4,
                            blurRadius: 0,
                          ),
                          BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                np?.stringPosition ?? '0:00',
                style: const TextStyle(fontSize: 11, color: lxTextDim),
              ),
              Text(
                np?.stringDuration ?? '0:00',
                style: const TextStyle(fontSize: 11, color: lxTextDim),
              ),
            ],
          ),
        ],
      );
    });
  }

  Widget _transport() {
    return Obx(() {
      final isPlaying = _mediaController.nowPlaying.value?.isPlaying ?? false;
      final enabled = !_mediaController.isLoadingMedia.value;

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _iconBtn(
            icon: Icons.shuffle_rounded,
            size: 36,
            color: lxTextDim,
            onTap: () {},
          ),
          _iconBtn(
            icon: Icons.skip_previous_rounded,
            size: 48,
            color: enabled ? lxText : lxTextFaint,
            onTap: enabled
                ? () => _mediaController
                    .sendMediaCommand(MediaActions.mediaPrevious)
                : null,
          ),
          GestureDetector(
            onTap: enabled
                ? () => _mediaController
                    .sendMediaCommand(MediaActions.mediaPlayPause)
                : null,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: enabled ? lxAccent : lxGlass2,
                boxShadow: enabled
                    ? const [
                        BoxShadow(
                          color: Color(0x6600E5FF),
                          blurRadius: 0,
                          spreadRadius: 1,
                        ),
                        BoxShadow(color: Color(0x8000E5FF), blurRadius: 30),
                      ]
                    : [],
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 32,
                color: enabled ? lxBg : lxTextFaint,
              ),
            ),
          ),
          _iconBtn(
            icon: Icons.skip_next_rounded,
            size: 48,
            color: enabled ? lxText : lxTextFaint,
            onTap: enabled
                ? () =>
                    _mediaController.sendMediaCommand(MediaActions.mediaNext)
                : null,
          ),
          _iconBtn(
            icon: Icons.repeat_rounded,
            size: 36,
            color: lxTextDim,
            onTap: () {},
          ),
        ],
      );
    });
  }

  Widget _volumeRow(BuildContext context) {
    return LxGlass(
      padding: const EdgeInsets.all(14),
      child: Obx(
        () => Row(
          children: [
            GestureDetector(
              onTap: _mediaController.setMuted,
              child: Icon(
                _mediaController.isMuted.value
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                size: 16,
                color: lxTextDim,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  activeTrackColor: lxText,
                  inactiveTrackColor: lxHairlineHi,
                  thumbColor: lxText,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 5),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 12),
                  overlayColor: lxAccent.withValues(alpha: 0.15),
                ),
                child: Slider(
                  value: _mediaController.volume.value.clamp(0, 100),
                  min: 0,
                  max: 100,
                  onChanged: (v) => _mediaController.volume.value = v,
                  onChangeEnd: _mediaController.slideVolume,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 28,
              child: Text(
                '${_mediaController.volume.value.toInt()}',
                style: const TextStyle(fontSize: 11, color: lxTextDim),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _outputRow() {
    final app =
        _mediaController.nowPlaying.value?.application ?? 'Player';
    return LxGlass(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.desktop_mac_rounded, size: 14, color: lxAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Output',
                  style: TextStyle(fontSize: 12, color: lxTextDim),
                ),
                Text(
                  app,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 16,
            color: lxTextGhost,
          ),
        ],
      ),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required double size,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(icon, size: size * 0.5, color: color),
      ),
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x14000000)
      ..strokeWidth = 1;

    double y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      y += 6;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
