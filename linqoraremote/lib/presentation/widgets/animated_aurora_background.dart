import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AnimatedAuroraBackground extends StatelessWidget {
  final Widget child;

  const AnimatedAuroraBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Base
          Container(
            color: const Color(0xFF0A0C10),
          ),
          
          // Aurora Blobs
          _AuroraBlob(
            color: const Color(0xFF00E5FF).withOpacity(0.15),
            size: 400,
            initialOffset: const Offset(-100, -100),
            duration: 15.seconds,
          ),
          _AuroraBlob(
            color: const Color(0xFFD0BCFF).withOpacity(0.1),
            size: 500,
            initialOffset: const Offset(200, 300),
            duration: 20.seconds,
          ),
          _AuroraBlob(
            color: const Color(0xFF00E5FF).withOpacity(0.1),
            size: 300,
            initialOffset: const Offset(100, 600),
            duration: 12.seconds,
          ),
          
          // Content
          child,
        ],
      ),
    );
  }
}

class _AuroraBlob extends StatelessWidget {
  final Color color;
  final double size;
  final Offset initialOffset;
  final Duration duration;

  const _AuroraBlob({
    required this.color,
    required this.size,
    required this.initialOffset,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: initialOffset.dx,
      top: initialOffset.dy,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withOpacity(0),
            ],
          ),
        ),
      )
      .animate(onPlay: (controller) => controller.repeat(reverse: true))
      .move(
        begin: Offset.zero,
        end: Offset(Random().nextDouble() * 100 - 50, Random().nextDouble() * 100 - 50),
        duration: duration,
        curve: Curves.easeInOut,
      )
      .scale(
        begin: const Offset(1, 1),
        end: const Offset(1.2, 1.2),
        duration: duration,
        curve: Curves.easeInOut,
      ),
    );
  }
}
