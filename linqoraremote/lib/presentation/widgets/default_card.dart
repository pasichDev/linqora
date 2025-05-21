import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DefaultCard extends StatelessWidget {
  final Widget child;

  const DefaultCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Get.theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: child,
    );
  }
}
