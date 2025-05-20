import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
            _homeController.selectedMenuIndex.value >= 0
                ? Column(
                  key: const ValueKey('detail_view'),
                  children: [
                    Expanded(
                      child:
                          menuOptions[_homeController.selectedMenuIndex.value]
                              .view,
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
                            _homeController.hostInfo.value != null
                                ? HostInfoCard(
                                  host: _homeController.hostInfo.value!,
                                  refresh: _homeController.refreshHostInfo,
                                  toggleShowHostFull:
                                      _homeController.toggleShowHostFull,
                                  isExpanded:
                                      _homeController.showHostFull.value,
                                )
                                : const HostInfoCardSkeleton(),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: GridView.builder(
                              padding: const EdgeInsets.only(
                                left: 16,
                                right: 16,
                                top: 5,
                                bottom: 16,
                              ),
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
                                    onTap:
                                        () => _homeController.selectMenuItem(
                                          index,
                                        ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
      );
    });
  }
}
