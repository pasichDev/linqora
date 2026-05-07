import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/themes/lx_theme.dart';

// Circular progress ring with a centered label.
class LxRing extends StatelessWidget {
  final double value;        // 0–100
  final double size;
  final double strokeWidth;
  final Color color;
  final String? label;       // eyebrow below the number

  const LxRing({
    super.key,
    required this.value,
    this.size = 80,
    this.strokeWidth = 3,
    this.color = lxAccent,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final numStr = value.toInt().toString();
    final numFontSize = size * 0.26;
    final labelFontSize = size * 0.12;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          value: value.clamp(0, 100),
          color: color,
          strokeWidth: strokeWidth,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: numStr,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: numFontSize,
                        fontWeight: FontWeight.w600,
                        color: lxText,
                        letterSpacing: -0.6,
                      ),
                    ),
                    TextSpan(
                      text: '%',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: numFontSize * 0.55,
                        color: lxTextDim,
                      ),
                    ),
                  ],
                ),
              ),
              if (label != null)
                Text(
                  label!.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: labelFontSize,
                    fontWeight: FontWeight.w500,
                    color: lxTextFaint,
                    letterSpacing: 1.0,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;
  final double strokeWidth;

  _RingPainter({
    required this.value,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth - 1;
    final trackPaint = Paint()
      ..color = lxHairlineHi
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    final sweep = 2 * math.pi * (value / 100);
    final arcPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color;
}
