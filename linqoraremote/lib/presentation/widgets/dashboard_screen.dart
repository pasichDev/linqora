import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/data/models/host_system_info.dart';
import 'package:linqoraremote/presentation/widgets/shimmer_effect.dart';

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
                : Column(
                  key: const ValueKey('grid_view'),
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: Obx(
                        () =>
                            controller.hostInfo.value != null
                                ? HostInfoCard(host: controller.hostInfo.value!)
                                : const HostInfoCardSkeleton(),
                      ),
                    ),

                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
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
                    ),
                  ],
                ),
      );
    });
  }
}

class HostInfoCard extends StatelessWidget {
  final HostSystemInfo host;

  const HostInfoCard({required this.host, super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              host.os,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              "${host.cpuModel}, ${host.cpuFrequency} MHz, ${host.cpuPhysicalCores}/${host.cpuLogicalCores} cores",
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            Text(
              "RAM: ${host.virtualMemoryTotal} GB",
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HostInfoCardSkeleton extends StatelessWidget {
  const HostInfoCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            ShimmerEffect(height: 18, width: 120),
            const SizedBox(height: 8),
            ShimmerEffect(height: 14, width: double.infinity),
            const SizedBox(height: 8),
            ShimmerEffect(height: 14, width: 100),
          ],
        ),
      ),
    );
  }
}
