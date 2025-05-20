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
      title: const Text('Підтвердження'),
      content: Text(
        'Ви впевнені, що хочете розірвати з\'єднання?',
        style: Get.textTheme.bodyMedium,
      ),
      actions: [
        TextButton(
          onPressed: () {
            Get.back(result: false);
            if (onCancel != null) onCancel!();
          },
          child: const Text('Скасувати'),
        ),
        TextButton(
          onPressed: () {
            Get.back(result: true);
            onConfirm();
          },
          child: const Text('Так'),
        ),
      ],
    );
  }
}
