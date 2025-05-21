import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const SectionHeader({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Get.theme.colorScheme.primary, size: 16),
        const SizedBox(width: 8),
        Text(
          title,
          style: Get.textTheme.titleMedium!.copyWith(
            color: Get.theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
