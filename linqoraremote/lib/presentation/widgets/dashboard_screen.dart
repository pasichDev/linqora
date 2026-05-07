import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:linqoraremote/presentation/widgets/animated_aurora_background.dart';

import '../controllers/device_home_controller.dart';
import '../dashboard_items.dart';
import 'host_info_card.dart';
import 'menu_option_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DeviceHomeController _homeController;

  @override
  void initState() {
    super.initState();
    _homeController = Get.find<DeviceHomeController>();
  }

  @override
  void dispose() {
    if (_isControllerRegistered<DeviceHomeController>()) {
      Get.delete<DeviceHomeController>();
    }
    super.dispose();
  }

  bool _isControllerRegistered<T>() {
    return Get.isRegistered<T>();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedAuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Obx(() {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.1, 0.0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart)),
                  child: child,
                ),
              );
            },
            child: _homeController.selectedMenuIndex.value >= 0
                ? Column(
                    key: const ValueKey('detail_view'),
                    children: [
                      Expanded(
                        child: menuOptions[_homeController.selectedMenuIndex.value].view,
                      ),
                    ],
                  )
                : Column(
                    key: const ValueKey('grid_view'),
                    children: [
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: Obx(() => _homeController.hostInfo.value != null
                            ? Padding(
                                padding: const EdgeInsets.all(20),
                                child: HostInfoCard(
                                  host: _homeController.hostInfo.value!,
                                  refresh: _homeController.refreshHostInfo,
                                  toggleShowHostFull: _homeController.toggleShowHostFull,
                                  isExpanded: _homeController.showHostFull.value,
                                ),
                              ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.1)
                            : const Padding(
                                padding: EdgeInsets.all(20),
                                child: HostInfoCardSkeleton(),
                              )),
                      ),
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.1,
                          ),
                          itemCount: menuOptions.length,
                          itemBuilder: (context, index) {
                            return Hero(
                              tag: 'menu_item_$index',
                              child: MenuOptionCard(
                                title: menuOptions[index].title,
                                icon: menuOptions[index].icon,
                                onTap: () => _homeController.selectMenuItem(index),
                              ),
                            ).animate().fadeIn(delay: (index * 50).ms, duration: 500.ms).scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack);
                          },
                        ),
                      ),
                    ],
                  ),
          );
        }),
      ),
    );
  }
}
