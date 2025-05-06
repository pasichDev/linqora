import 'package:flutter/material.dart';
import 'package:linqoraremote/presentation/widgets/mouse_control_view.dart';
import 'package:linqoraremote/presentation/widgets/monitoring_view.dart';

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
    title: 'Моніторинг',
    icon: Icons.monitor_heart_outlined,
    view: MonitoringView(),
  ),
  MenuOption(
    title: 'Керування мишкою',
    icon: Icons.mouse,
    view: MouseControlView(),
  ),
];
