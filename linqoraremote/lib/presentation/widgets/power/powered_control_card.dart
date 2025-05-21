import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/power_controller.dart';
import '../default_card.dart';

class PowerControlCard extends StatelessWidget {
  final void Function(int) fetchAction;

  const PowerControlCard({required this.fetchAction, super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlButton(
              context,
              Icons.power_settings_new,
              'shut_down'.tr,
              () => fetchAction(PowerActions.shutDown),
              Colors.red.shade300,
            ),
            _buildControlButton(
              context,
              Icons.restart_alt,
              'restart'.tr,
              () => fetchAction(PowerActions.restart),
              Get.theme.colorScheme.secondary,
            ),
            _buildControlButton(
              context,
              Icons.lock_outline,
              'lock'.tr,
              () => fetchAction(PowerActions.lock),
              Get.theme.colorScheme.secondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton(
    BuildContext context,
    IconData iconData,
    String label,
    VoidCallback onPressed,
    Color iconColor,
  ) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconData, size: 32, color: iconColor),
            const SizedBox(height: 8),
            Text(
              label,
              style: Get.textTheme.titleMedium!.copyWith(
                color: Get.theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
