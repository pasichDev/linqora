import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/core/themes/lx_theme.dart';
import 'package:linqoraremote/data/providers/websocket_provider.dart';
import 'package:linqoraremote/presentation/widgets/lx_glass.dart';
import 'package:linqoraremote/presentation/widgets/lx_header.dart';

import '../controllers/mouse_controller.dart';

class TouchpadView extends StatefulWidget {
  const TouchpadView({super.key});

  @override
  State<TouchpadView> createState() => _TouchpadViewState();
}

class _TouchpadViewState extends State<TouchpadView>
    with TickerProviderStateMixin {
  late MouseController _mouse;

  final List<_Ripple> _ripples = [];
  Offset _pointerPos = const Offset(0.5, 0.5); // normalised 0-1

  // Scroll accumulator for the centre scroll button and two-finger scroll.
  double _scrollAccum = 0;
  static const _notchThreshold = 40.0;

  // Two-finger gesture tracking.
  double _prevScale = 1.0;
  DateTime _lastPinch = DateTime.fromMillisecondsSinceEpoch(0);
  static const _pinchThrottle = Duration(milliseconds: 100);

  @override
  void initState() {
    super.initState();
    _mouse = Get.put(
      MouseController(webSocketProvider: Get.find<WebSocketProvider>()),
    );
  }

  @override
  void dispose() {
    for (final r in _ripples) {
      r.anim.dispose();
    }
    if (Get.isRegistered<MouseController>()) Get.delete<MouseController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      child: Column(
        children: [
          LxHeader(
            title: 'Touchpad',
            eyebrow: 'Connected',
            showBack: false,
            action: LxGlass(
              borderRadius: BorderRadius.circular(12),
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Center(
                  child: Icon(
                    Icons.more_horiz_rounded,
                    size: 14,
                    color: lxTextDim,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: LxGlass(
              child: Column(
                children: [
                  Expanded(child: _touchSurface()),
                  const Divider(height: 1, color: lxHairline),
                  _mouseButtons(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _sensitivityRow(),
        ],
      ),
    );
  }

  // ─── Touch surface ───────────────────────────────────────────────────────────

  Widget _touchSurface() {
    return GestureDetector(
      onScaleStart: (_) {
        _prevScale = 1.0;
      },
      onScaleUpdate: (d) {
        if (d.pointerCount == 1) {
          // Single finger — move cursor.
          _mouse.moveMouse(d.focalPointDelta.dx, d.focalPointDelta.dy);
          setState(() {
            final box = context.findRenderObject() as RenderBox?;
            if (box != null) {
              final local = box.globalToLocal(d.focalPoint);
              _pointerPos = Offset(
                (local.dx / box.size.width).clamp(0.0, 1.0),
                (local.dy / box.size.height).clamp(0.0, 1.0),
              );
            }
          });
        } else {
          final scaleDeviation = (d.scale - 1.0).abs();
          if (scaleDeviation < 0.05) {
            // Two-finger pan — scroll.
            _scrollAccum += d.focalPointDelta.dy;
            while (_scrollAccum >= _notchThreshold) {
              HapticFeedback.selectionClick();
              _mouse.scroll(-1);
              _scrollAccum -= _notchThreshold;
            }
            while (_scrollAccum <= -_notchThreshold) {
              HapticFeedback.selectionClick();
              _mouse.scroll(1);
              _scrollAccum += _notchThreshold;
            }
          } else {
            // Pinch gesture — zoom, throttled to 100ms.
            final now = DateTime.now();
            if (now.difference(_lastPinch) >= _pinchThrottle) {
              _lastPinch = now;
              final direction = d.scale > _prevScale ? 1 : -1;
              _mouse.pinchZoom(direction);
            }
            _prevScale = d.scale;
          }
        }
      },
      onScaleEnd: (_) {
        _scrollAccum = 0;
        _prevScale = 1.0;
      },
      onTap: () {
        HapticFeedback.lightImpact();
        _mouse.leftClick();
        _addRipple();
      },
      onDoubleTap: () {
        HapticFeedback.lightImpact();
        _mouse.doubleClick();
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _mouse.rightClick();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(lxRadiusCard),
          topRight: Radius.circular(lxRadiusCard),
        ),
        child: Stack(
          children: [
            // Dot-grid background
            Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),

            // Ripple rings
            ..._ripples.map(
              (r) => AnimatedBuilder(
                animation: r.anim,
                builder: (_, __) => Positioned.fill(
                  child: CustomPaint(painter: _RipplePainter(ripple: r)),
                ),
              ),
            ),

            // Cyan pointer dot — uses LayoutBuilder so normalised coords map
            // to real pixels.
            Positioned.fill(
              child: LayoutBuilder(
                builder: (_, constraints) {
                  final x = _pointerPos.dx * constraints.maxWidth - 4;
                  final y = _pointerPos.dy * constraints.maxHeight - 4;
                  return Stack(
                    children: [
                      Positioned(
                        left: x,
                        top: y,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: lxAccent,
                            boxShadow: [
                              BoxShadow(
                                color: lxAccent,
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Corner hint
            const Positioned(
              top: 16,
              left: 16,
              child: Text(
                'DRAG · TAP · 2F SCROLL · PINCH ZOOM',
                style: TextStyle(
                  fontSize: 9,
                  color: lxTextFaint,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Right-edge scroll strip (decorative thumb)
            Positioned(
              top: 14,
              bottom: 14,
              right: 12,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: lxHairline,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  heightFactor: 0.15,
                  alignment: Alignment.topCenter,
                  child: Container(
                    decoration: BoxDecoration(
                      color: lxAccent.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Mouse buttons row ───────────────────────────────────────────────────────

  Widget _mouseButtons() {
    return SizedBox(
      height: 76,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _mouse.leftClick();
              },
              child: const Center(
                child: Text(
                  'LEFT',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.4,
                    color: lxTextFaint,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          Container(width: 1, color: lxHairline),
          SizedBox(
            width: 76,
            child: GestureDetector(
              onVerticalDragUpdate: (d) {
                _scrollAccum += d.delta.dy;
                while (_scrollAccum >= _notchThreshold) {
                  HapticFeedback.selectionClick();
                  _mouse.scroll(-1); // drag down = scroll down
                  _scrollAccum -= _notchThreshold;
                }
                while (_scrollAccum <= -_notchThreshold) {
                  HapticFeedback.selectionClick();
                  _mouse.scroll(1); // drag up = scroll up
                  _scrollAccum += _notchThreshold;
                }
              },
              onVerticalDragEnd: (_) => _scrollAccum = 0,
              child: const Center(
                child: Icon(
                  Icons.unfold_more_rounded,
                  size: 16,
                  color: lxTextDim,
                ),
              ),
            ),
          ),
          Container(width: 1, color: lxHairline),
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _mouse.rightClick();
              },
              child: const Center(
                child: Text(
                  'RIGHT',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.4,
                    color: lxTextFaint,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Sensitivity row ─────────────────────────────────────────────────────────

  Widget _sensitivityRow() {
    return Row(
      children: [
        const Text(
          'SENSITIVITY',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.4,
            color: lxTextFaint,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Obx(
            () => SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: lxAccent,
                inactiveTrackColor: lxHairlineHi,
                thumbColor: lxText,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
                overlayColor: Colors.transparent,
              ),
              child: Slider(
                value: _mouse.sensitivity.value,
                min: 0.5,
                max: 8.0,
                divisions: 30,
                onChanged: (v) => _mouse.sensitivity.value = v,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Obx(
          () => SizedBox(
            width: 36,
            child: Text(
              '${_mouse.sensitivity.value.toStringAsFixed(1)}×',
              style: const TextStyle(fontSize: 11, color: lxTextDim),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Ripple helpers ───────────────────────────────────────────────────────────

  void _addRipple() {
    final ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    final ripple = _Ripple(pos: _pointerPos, anim: ctrl);
    ctrl
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _ripples.removeWhere((r) => r.anim.isCompleted));
        }
      })
      ..forward();

    setState(() {
      _ripples.add(ripple);
      if (_ripples.length > 4) {
        _ripples.removeAt(0);
      }
    });
  }
}

// ─── Data classes ─────────────────────────────────────────────────────────────

class _Ripple {
  final Offset pos;
  final AnimationController anim;
  _Ripple({required this.pos, required this.anim});
}

// ─── Custom painters ─────────────────────────────────────────────────────────

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = lxHairlineHi.withValues(alpha: 0.8);
    const spacing = 22.0;
    for (double x = 0; x <= size.width; x += spacing) {
      for (double y = 0; y <= size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RipplePainter extends CustomPainter {
  final _Ripple ripple;
  _RipplePainter({required this.ripple});

  @override
  void paint(Canvas canvas, Size size) {
    final t = ripple.anim.value;
    final cx = ripple.pos.dx * size.width;
    final cy = ripple.pos.dy * size.height;
    for (int i = 1; i <= 3; i++) {
      final radius = 4 + (60 * i / 3) * t;
      final opacity = (1 - t) * (0.4 / i);
      final paint = Paint()
        ..color = lxAccent.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.ripple.anim.value != ripple.anim.value;
}
