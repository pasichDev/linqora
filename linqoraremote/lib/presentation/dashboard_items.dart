import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/presentation/widgets/monitoring_view.dart';
import 'package:linqoraremote/presentation/widgets/powermanagment_view.dart';

import 'widgets/media_view.dart';

class MenuOption {
  final String title;
  final IconData icon;
  final Widget view;

  const MenuOption({
    required this.title,
    required this.icon,
    required this.view,
  });
}

final menuOptions = [
  MenuOption(
    title: 'monitoring'.tr,
    icon: Icons.monitor_heart_outlined,
    view: MonitoringView(),
  ),
  MenuOption(title: 'media'.tr, icon: Icons.volume_up, view: MediaScreenView()),
  MenuOption(
    title: 'power'.tr,
    icon: Icons.energy_savings_leaf_outlined,
    view: PowerManagementView(),
  ),
];
