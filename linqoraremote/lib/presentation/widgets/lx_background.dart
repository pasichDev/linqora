import 'package:flutter/material.dart';
import '../../core/themes/lx_theme.dart';

// Page-level background: deep space black + radial gradients + faint grid.
// Replaces AnimatedAuroraBackground for a simpler, design-spec-accurate version.
class LxBackground extends StatelessWidget {
  final Widget child;

  const LxBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: lxBg,
      child: Stack(
        children: [
          // Radial gradients
          Positioned.fill(
            child: CustomPaint(painter: _BgPainter()),
          ),
          // Faint dot-grid texture
          Positioned.fill(
            child: Opacity(
              opacity: 0.07,
              child: _GridTexture(),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _BgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Top radial: bgGrad at 50%/0%
    final topGrad = RadialGradient(
      center: const Alignment(0, -1),
      radius: 1.1,
      colors: [lxBgGrad, const Color(0x001A1F2B)],
      stops: const [0.0, 0.55],
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = topGrad.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      ),
    );
    // Bottom-right radial: subtle cyan glow
    final brGrad = RadialGradient(
      center: const Alignment(1, 1),
      radius: 0.8,
      colors: [const Color(0x0D00E5FF), const Color(0x0000E5FF)],
      stops: const [0.0, 0.6],
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = brGrad.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      ),
    );
  }

  @override
  bool shouldRepaint(_BgPainter old) => false;
}

class _GridTexture extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GridPainter());
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 48.0;
    final paint = Paint()
      ..color = const Color(0x14FFFFFF)
      ..strokeWidth = 0.5;
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}
