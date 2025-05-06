import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/presentation/controllers/device_home_controller.dart';
class MouseControlView extends StatelessWidget {
  const MouseControlView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DeviceHomeController>();
    final sensitivity = 1.0; // Множитель чувствительности
   // controller.joinMouseRoom();

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onPanUpdate: (details) {
              // Преобразуем дельту в целые числа
              final dx = (details.delta.dx * sensitivity).round();
              final dy = (details.delta.dy * sensitivity).round();
              if (dx == 0 && dy == 0) return;
              controller.webSocketProvider.sendCursorCommand(
                dx,
                dy,
                0, // MouseMove
              );
            },
            onTapDown: (details) {
              controller.webSocketProvider.sendCursorCommand(
                0,
                0,
                1, // MouseClick
              );
            },
            onDoubleTapDown: (details) {
              controller.webSocketProvider.sendCursorCommand(
                0,
                0,
                2, // MouseDouble
              );
            },
            onLongPress: () {
              controller.webSocketProvider.sendCursorCommand(
                0,
                0,
                3, // MouseRight
              );
            },
            child: Container(
              width: double.infinity,
              height: 400,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Text('Тачпад'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}