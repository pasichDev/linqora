import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/themes/lx_theme.dart';

// Glass surface — 40px blur, 1px hairline, low-op fill.
// [accent] adds cyan border + soft glow.
// [hi] uses lxGlass2 fill instead of lxGlass.
class LxGlass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final bool accent;
  final bool hi;
  final VoidCallback? onTap;

  const LxGlass({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.accent = false,
    this.hi = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(lxRadiusCard);
    final border = accent
        ? Border.all(color: const Color(0x59000000).withAlpha(0) /*unused*/, width: 0)
        : Border.all(color: lxHairline, width: 1);
    final accentBorder = Border.all(color: const Color(0x5900E5FF), width: 1);
    final fill = hi ? lxGlass2 : lxGlass;

    Widget content = ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: br,
            border: accent ? accentBorder : border,
            boxShadow: accent
                ? [
                    BoxShadow(
                      color: lxAccent.withValues(alpha: 0.4 * 0.25),
                      blurRadius: 30,
                      spreadRadius: -10,
                    ),
                  ]
                : null,
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }
}
