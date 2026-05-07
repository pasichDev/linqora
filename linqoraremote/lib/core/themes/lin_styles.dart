import 'dart:ui';
import 'package:flutter/material.dart';

class LinStyles {
  static BoxDecoration glassDecoration(BuildContext context, {double opacity = 0.1, double blur = 15.0}) {
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface.withOpacity(opacity),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: Colors.white.withOpacity(0.1),
        width: 1.5,
      ),
    );
  }

  static Widget glassMorphism({
    required Widget child,
    double blur = 15.0,
    double opacity = 0.1,
    BorderRadius? borderRadius,
  }) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: borderRadius ?? BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  static LinearGradient auroraGradient = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0A0C10),
      Color(0xFF1A1F2B),
      Color(0xFF0A0C10),
    ],
  );

  static List<BoxShadow> premiumShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.3),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: const Color(0xFF00E5FF).withOpacity(0.1),
      blurRadius: 30,
      offset: const Offset(0, 5),
    ),
  ];
}
