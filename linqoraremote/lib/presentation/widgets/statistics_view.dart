import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/device_home_controller.dart';

class StatisticsView extends StatelessWidget {
  const StatisticsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DeviceHomeController>();
    final messages = controller.webSocketProvider.messages;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Статистика',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        Expanded(
          child: Obx(
            () =>
                messages.isEmpty
                    ? const Center(child: Text('Немає даних'))
                    : ListView.builder(
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        return ListTile(title: Text(messages[index]));
                      },
                    ),
          ),
        ),
      ],
    );
  }
}
