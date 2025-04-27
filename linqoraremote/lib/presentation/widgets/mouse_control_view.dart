import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/device_home_controller.dart';

class MouseControlView extends StatelessWidget {
  const MouseControlView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DeviceHomeController>();

    return Column(
      children: [
        Expanded(
          child: Center(
            child: GestureDetector(
              onPanUpdate: (details) {
                // Відправка позиції миші через WebSocket
                controller.webSocketProvider.send(
                  '{"type":"mouse_move","x":${details.delta.dx},"y":${details.delta.dy}}',
                );
              },
              onTap: () {
                // Відправка кліку миші через WebSocket
                controller.webSocketProvider.send(
                  '{"type":"mouse_click","button":"left"}',
                );
              },
              onDoubleTap: () {
                // Відправка подвійного кліку миші через WebSocket
                controller.webSocketProvider.send(
                  '{"type":"mouse_double_click","button":"left"}',
                );
              },
              onLongPress: () {
                // Відправка правого кліку миші через WebSocket
                controller.webSocketProvider.send(
                  '{"type":"mouse_click","button":"right"}',
                );
              },
              child: Container(
                width: double.infinity,
                height: 400,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(child: Text('Тачпад')),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
