import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/presentation/widgets/clipboard_view.dart';
import 'package:linqoraremote/presentation/widgets/display_view.dart';
import 'package:linqoraremote/presentation/widgets/keyboard_view.dart';
import 'package:linqoraremote/presentation/widgets/monitoring_view.dart';
import 'package:linqoraremote/presentation/widgets/powermanagement_view.dart';
import 'package:linqoraremote/presentation/widgets/process_view.dart';
import 'package:linqoraremote/presentation/widgets/monitor_view.dart';
import 'package:linqoraremote/presentation/widgets/startup_view.dart';
import 'package:linqoraremote/presentation/widgets/touchpad_view.dart';

import 'widgets/filebrowser_view.dart';
import 'widgets/media_view.dart';
import 'widgets/scripts_view.dart';

class MenuOption {
  final String title;
  final IconData icon;
  final Widget view;
  final String? requiredCap; // null = always visible

  const MenuOption({
    required this.title,
    required this.icon,
    required this.view,
    this.requiredCap,
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
  MenuOption(
    title: 'touchpad'.tr,
    icon: Icons.mouse_outlined,
    view: TouchpadView(),
  ),
  MenuOption(
    title: 'scripts'.tr,
    icon: Icons.code_rounded,
    view: const ScriptsView(),
    requiredCap: 'scripts',
  ),
  MenuOption(
    title: 'files'.tr,
    icon: Icons.folder_outlined,
    view: const FileBrowserView(),
    requiredCap: 'file_browser',
  ),
  MenuOption(
    title: 'keyboard'.tr,
    icon: Icons.keyboard_outlined,
    view: const KeyboardView(),
    requiredCap: 'keyboard_hotkeys',
  ),
  MenuOption(
    title: 'clipboard'.tr,
    icon: Icons.content_paste_outlined,
    view: const ClipboardView(),
    requiredCap: 'clipboard',
  ),
  MenuOption(
    title: 'display'.tr,
    icon: Icons.brightness_medium_outlined,
    view: const DisplayView(),
    requiredCap: 'display_sleep_wake',
  ),
  MenuOption(
    title: 'Processes',
    icon: Icons.memory_rounded,
    view: const ProcessView(),
    requiredCap: 'process_manager',
  ),
  MenuOption(
    title: 'Startup',
    icon: Icons.power_settings_new_rounded,
    view: const StartupView(),
    requiredCap: 'startup_manager',
  ),
  MenuOption(
    title: 'Monitors',
    icon: Icons.desktop_windows_outlined,
    view: const MonitorView(),
    requiredCap: 'monitor_control',
  ),
];
