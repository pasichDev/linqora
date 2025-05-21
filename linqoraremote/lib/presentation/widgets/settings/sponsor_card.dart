import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/presentation/widgets/settings/section_header.dart';

import '../../../core/constants/urls.dart';
import '../../../core/utils/lauch_url.dart';

class SponsorCard extends StatelessWidget {
  final VoidCallback? onClose;
  const SponsorCard({this.onClose, super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,

      color: Get.theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SectionHeader(
                  title: "support_project_title".tr,
                  icon: Icons.favorite_outline,
                ),

                if (onClose != null)
                  InkWell(onTap: onClose, child: Icon(Icons.close, size: 20)),
              ],
            ),
            const SizedBox(height: 20),
            Column(
              children: [
                Text(
                  'support_project_description'.tr,
                  style: TextStyle(fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.favorite),
                      label: Text('support_project'.tr),
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
                      label: Text('send_feedback'.tr),
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
