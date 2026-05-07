import 'package:flutter/material.dart';
import '../../core/themes/lx_theme.dart';

class LxSparkline extends StatelessWidget {
  final List<num> data;
  final double width;
  final double height;
  final Color color;
  final bool fill;
  final double strokeWidth;

  const LxSparkline({
    super.key,
    required this.data,
    required this.width,
    required this.height,
    this.color = lxAccent,
    this.fill = true,
    this.strokeWidth = 1.4,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _SparklinePainter(
          data: data,
          color: color,
          fill: fill,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<num> data;
  final Color color;
  final bool fill;
  final double strokeWidth;

  _SparklinePainter({
    required this.data,
    required this.color,
    required this.fill,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final doubles = data.map((e) => e.toDouble()).toList();
    final minV = doubles.reduce((a, b) => a < b ? a : b);
    final maxV = doubles.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs();
    final step = size.width / (doubles.length - 1);

    List<Offset> pts = [];
    for (int i = 0; i < doubles.length; i++) {
      final x = i * step;
      final norm = range == 0 ? 0.5 : (doubles[i] - minV) / range;
      final y = size.height - (norm * size.height * 0.92) - 2;
      pts.add(Offset(x, y));
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2);

    final linePath = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length; i++) {
      linePath.lineTo(pts[i].dx, pts[i].dy);
    }

    if (fill) {
      final fillPath = Path()
        ..moveTo(pts[0].dx, pts[0].dy);
      for (int i = 1; i < pts.length; i++) {
        fillPath.lineTo(pts[i].dx, pts[i].dy);
      }
      fillPath
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.28),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, fillPaint);
    }

    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.data != data || old.color != color;
}
