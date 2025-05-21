import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DisconnectConfirmationDialog extends StatelessWidget {
  final Function() onConfirm;
  final Function()? onCancel;

  const DisconnectConfirmationDialog({
    super.key,
    required this.onConfirm,
    this.onCancel,
  });

  static Future<bool?> show({
    required Function() onConfirm,
    Function()? onCancel,
  }) {
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
        TextButton(
          onPressed: () {
            Get.back(result: false);
            if (onCancel != null) onCancel!();
          },
          child: Text('cancel'.tr),
        ),
        TextButton(
          onPressed: () {
            Get.back(result: true);
            onConfirm();
          },
          child: Text('disconnect'.tr),
        ),
      ],
    );
  }
}
