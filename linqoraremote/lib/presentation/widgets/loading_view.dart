import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class LoadingView extends StatelessWidget {
  final String? text;
  final double size;
  final Color? color;

  const LoadingView({super.key, this.text, this.size = 80, this.color});

  @override
  Widget build(BuildContext context) {
    final loadingColor = color ?? Theme.of(context).colorScheme.onSurface;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LoadingAnimationWidget.fourRotatingDots(
            color: loadingColor,
            size: size,
          ),
          if (text != null) ...[
            const SizedBox(height: 16),
            Text(
              text!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: loadingColor),
            ),
          ],
        ],
      ),
    );
  }
}
