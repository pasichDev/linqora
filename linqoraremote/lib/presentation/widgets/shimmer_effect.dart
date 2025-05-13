import 'package:flutter/material.dart';

class ShimmerEffect extends StatelessWidget {
  final double height;
  final double width;
  final BorderRadius? borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerEffect({
    super.key,
    required this.height,
    required this.width,
    this.borderRadius,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: baseColor ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
        borderRadius: borderRadius ?? BorderRadius.circular(4),
      ),
      child: ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) {
          return LinearGradient(
            colors: [
              Colors.transparent,
              highlightColor ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
            begin: const Alignment(-1.0, -0.5),
            end: const Alignment(1.0, 0.5),
            tileMode: TileMode.clamp,
          ).createShader(bounds);
        },
        child: const SizedBox.expand(),
      ),
    );
  }
}