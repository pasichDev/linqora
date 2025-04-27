import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/device_home_controller.dart';
import 'menu_option_card.dart';
import 'mouse_control_view.dart';
import 'statistics_view.dart';

class DashboardScreen extends StatelessWidget {
  DashboardScreen({super.key});

  final List<Map<String, dynamic>> menuOptions = [
    {'title': 'Статистика', 'icon': Icons.bar_chart, 'view': StatisticsView()},
    {
      'title': 'Керування мишкою',
      'icon': Icons.mouse,
      'view': MouseControlView(),
    },
  ];

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DeviceHomeController>();

    return Obx(() {
      if (controller.selectedMenuIndex.value >= 0) {
        return Column(
          children: [
            Expanded(
              child: menuOptions[controller.selectedMenuIndex.value]['view'],
            ),
          ],
        );
      } else {
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: menuOptions.length,
          itemBuilder: (context, index) {
            return MenuOptionCard(
              title: menuOptions[index]['title'],
              icon: menuOptions[index]['icon'],
              onTap: () => controller.selectMenuItem(index),
            );
          },
        );
      }
    });
  }
}
