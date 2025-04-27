import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../controllers/device_home_controller.dart';

class ConnectScreen extends StatelessWidget {
  const ConnectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DeviceHomeController>();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        LoadingAnimationWidget.fourRotatingDots(
          color: Theme.of(context).colorScheme.onSurface,
          size: 60,
        ),
        const SizedBox(height: 30),
        Obx(
          () =>
              controller.mdnsConnectingStatus.value  ==
                  MDnsStatus.connected
                  ? Text(
                    "Знайдено пристрій з кодом: ${controller.deviceCode.value} \n Встановлюємо з'єднання через WebSocket...",
                    textAlign: TextAlign.center,
                  )
                  : controller.mdnsConnectingStatus.value ==
                      MDnsStatus.connecting
                  ? Obx(
                    () => Text(
                      "Пошук пристрою з кодом: ${controller.deviceCode.value}...\nБудь ласка, зачекайте.",
                      textAlign: TextAlign.center,
                    ),
                  )
                  : SizedBox(),
        ),

        const SizedBox(height: 40),
        OutlinedButton(
          onPressed: () => controller.cancelConnection(),
          style: OutlinedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            minimumSize: const Size(120, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Скасувати', style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }
}
