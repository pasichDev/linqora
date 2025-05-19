import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/urls.dart';
import '../../core/utils/lauch_url.dart';

class SponsorCard extends StatelessWidget {
  final VoidCallback? onClose;
  const SponsorCard({this.onClose, super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.favorite_outline,
                      color: Get.theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Поддержка проекта',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Get.theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                if (onClose != null)
                  InkWell(onTap: onClose, child: Icon(Icons.close, size: 20)),
              ],
            ),
            const SizedBox(height: 20),
            Column(
              children: [
                const Text(
                  'Linqora — это проект с открытым исходным кодом, разрабатываемый энтузиастами. Вы можете помочь проекту, став спонсором или поделившись отзывом.',
                  style: TextStyle(fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.favorite),
                      label: const Text('Поддержать проект'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Get.theme.colorScheme.primary,
                        foregroundColor: Get.theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => launchUrlHandler(supportLinqora),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.star_outline),
                      label: const Text('Оставить отзыв'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => launchUrlHandler(sendFeedback),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
