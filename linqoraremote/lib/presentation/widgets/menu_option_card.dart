import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MenuOptionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const MenuOptionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Get.theme.colorScheme.secondary),
            const SizedBox(height: 15),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Get.theme.colorScheme.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
