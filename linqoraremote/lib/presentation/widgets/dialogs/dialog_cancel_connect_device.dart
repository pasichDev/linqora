import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DisconnectConfirmationDialog extends StatelessWidget {
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  const DisconnectConfirmationDialog({
    super.key,
    this.onConfirm,
    this.onCancel,
  });

  static Future<bool?> show({VoidCallback? onConfirm, VoidCallback? onCancel}) {
    return Get.dialog<bool>(
      DisconnectConfirmationDialog(onConfirm: onConfirm, onCancel: onCancel),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('confirmation'.tr),
      content: Text(
        'cancel_connection_confirmation'.tr,
        style: Get.textTheme.bodyMedium,
      ),
      actions: [
        _buildActionButton(
          label: 'cancel'.tr,
          onPressed: () {
            Get.back(result: false);
            onCancel?.call();
          },
        ),
        _buildActionButton(
          label: 'disconnect'.tr,
          onPressed: () {
            Get.back(result: true);
            onConfirm?.call();
          },
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return TextButton(onPressed: onPressed, child: Text(label));
  }
}
