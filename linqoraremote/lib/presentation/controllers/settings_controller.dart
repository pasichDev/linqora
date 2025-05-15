import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class SettingsController extends GetxController {
  static const _kThemeMode = 'theme_mode';
  static const _kShowMetrics = 'show_metrics';
  static const _kEnableNotifications = 'enable_notifications';
  static const _kEnableAutoConnect = 'enable_auto_connect';
  static const _kKeepAliveInterval = 'keep_alive_interval';

  final _storage = GetStorage('settings');

  final Rx<ThemeMode> themeMode = ThemeMode.system.obs;
  final RxBool showMetrics = true.obs;
  final RxBool enableNotifications = true.obs;
  final RxBool enableAutoConnect = false.obs;
  final RxInt keepAliveInterval = 10.obs;

  @override
  void onInit() {
    super.onInit();
    loadSettings();
  }

  void loadSettings() {
    try {
      // Получаем сохраненные настройки или используем значения по умолчанию
      final themeModeValue = _storage.read<String>(_kThemeMode) ?? 'system';
      themeMode.value = _getThemeMode(themeModeValue);

      showMetrics.value = _storage.read<bool>(_kShowMetrics) ?? true;
      enableNotifications.value = _storage.read<bool>(_kEnableNotifications) ?? true;
      enableAutoConnect.value = _storage.read<bool>(_kEnableAutoConnect) ?? false;
      keepAliveInterval.value = _storage.read<int>(_kKeepAliveInterval) ?? 10;

      // Применяем тему сразу при загрузке
      Get.changeThemeMode(themeMode.value);
    } catch (e) {
      printError(info: 'Ошибка загрузки настроек: $e');
      // В случае ошибки используем значения по умолчанию
    }
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    try {
      themeMode.value = mode;
      await _storage.write(_kThemeMode, _getThemeModeString(mode));
      Get.changeThemeMode(mode);
    } catch (e) {
      printError(info: 'Ошибка сохранения темы: $e');
    }
  }

  Future<void> toggleShowMetrics(bool value) async {
    showMetrics.value = value;
    await _storage.write(_kShowMetrics, value);
  }

  Future<void> toggleNotifications(bool value) async {
    enableNotifications.value = value;
    await _storage.write(_kEnableNotifications, value);
  }

  Future<void> toggleAutoConnect(bool value) async {
    enableAutoConnect.value = value;
    await _storage.write(_kEnableAutoConnect, value);
  }

  Future<void> setKeepAliveInterval(int value) async {
    keepAliveInterval.value = value;
    await _storage.write(_kKeepAliveInterval, value);
  }

  ThemeMode _getThemeMode(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _getThemeModeString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      default:
        return 'system';
    }
  }
}