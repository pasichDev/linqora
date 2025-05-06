import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/device_home_controller.dart';
import '../dashboard_items.dart';
import 'menu_option_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DeviceHomeController>();

    return Obx(() {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child:
            controller.selectedMenuIndex.value >= 0
                ? Column(
                  key: const ValueKey('detail_view'),
                  children: [
                    Expanded(
                      child:
                          menuOptions[controller.selectedMenuIndex.value].view,
                    ),
                  ],
                )
                : GridView.builder(
                  key: const ValueKey('grid_view'),
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: menuOptions.length,
                  itemBuilder: (context, index) {
                    return Hero(
                      tag: 'menu_item_$index',
                      child: MenuOptionCard(
                        title: menuOptions[index].title,
                        icon: menuOptions[index].icon,
                        onTap: () => controller.selectMenuItem(index),
                      ),
                    );
                  },
                ),
      );
    });
  }
}
