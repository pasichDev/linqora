import 'package:flutter/material.dart';
import '../../core/themes/lx_theme.dart';
import 'lx_glass.dart';

// Standard screen header — back chevron · optional eyebrow + large title · action button
class LxHeader extends StatelessWidget {
  final String title;
  final String? eyebrow;
  final Widget? action;
  final bool showBack;
  final VoidCallback? onBack;
  final bool dense;

  const LxHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.action,
    this.showBack = true,
    this.onBack,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final pt = dense ? 8.0 : 14.0;
    final pb = dense ? 10.0 : 18.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(sp20, pt, sp20, pb),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showBack)
                _circleBtn(
                  child: const Icon(
                    Icons.chevron_left_rounded,
                    color: lxText,
                    size: 20,
                  ),
                  onTap: onBack ?? () => Navigator.of(context).maybePop(),
                )
              else
                const SizedBox(width: 36),
              const Spacer(),
              if (action != null) action! else const SizedBox(width: 36),
            ],
          ),
          if (eyebrow != null) ...[
            const SizedBox(height: 14),
            Text(
              eyebrow!.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.4,
                color: lxTextFaint,
              ),
            ),
          ],
          SizedBox(height: eyebrow != null ? 6 : 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
              color: lxText,
              height: 1.05,
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleBtn({required Widget child, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: LxGlass(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(child: child),
        ),
      ),
    );
  }
}
