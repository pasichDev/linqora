import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/core/constants/names.dart';
import 'package:linqoraremote/presentation/controllers/settings_controller.dart';
import 'package:linqoraremote/presentation/widgets/settings/sponsor_card.dart';

import '../../core/constants/urls.dart';
import '../../core/utils/lauch_url.dart';
import '../../generated/assets.dart';
import '../widgets/settings/section_header.dart';

class SettingsPage extends GetView<SettingsController> {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "settings".tr,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 8,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        children: [
          SponsorCard(),
          const SizedBox(height: 16),
          _buildThemeSection(context),
          const SizedBox(height: 16),
          _buildConnectionSection(context),
          const SizedBox(height: 16),
          _buildAboutSection(context),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, Widget child) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(padding: const EdgeInsets.all(16.0), child: child),
    );
  }

  Widget _buildThemeSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'design'.tr, icon: Icons.palette_outlined),
        _buildCard(
          context,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('app_theme'.tr, style: Get.textTheme.titleMedium),
              const SizedBox(height: 16),
              Obx(() => _buildThemeSelector(context)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemeSelector(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildThemeOption(
          context,
          'theme_set_system'.tr,
          Icons.settings_suggest_outlined,
          controller.themeMode.value == ThemeMode.system,
          () => controller.saveThemeMode(ThemeMode.system),
        ),
        _buildThemeOption(
          context,
          'theme_set_light'.tr,
          Icons.light_mode_outlined,
          controller.themeMode.value == ThemeMode.light,
          () => controller.saveThemeMode(ThemeMode.light),
        ),
        _buildThemeOption(
          context,
          'theme_set_dark'.tr,
          Icons.dark_mode_outlined,
          controller.themeMode.value == ThemeMode.dark,
          () => controller.saveThemeMode(ThemeMode.dark),
        ),
      ],
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    String label,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? Get.theme.colorScheme.primaryContainer : null,
          border: Border.all(
            color:
                isSelected
                    ? Get.theme.colorScheme.primary
                    : Get.theme.colorScheme.outline,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color:
                  isSelected
                      ? Get.theme.colorScheme.primary
                      : Get.theme.colorScheme.onSurface,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color:
                    isSelected
                        ? Get.theme.colorScheme.primary
                        : Get.theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'connecting'.tr, icon: Icons.link_outlined),
        _buildCard(
          context,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Obx(
                () => SwitchListTile(
                  title: Row(
                    children: [
                      Text('notification'.tr, style: Get.textTheme.titleMedium),
                      const SizedBox(width: 8),
                      if (!controller.notificationPermissionGranted.value &&
                          controller.enableNotifications.value)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'required_permission'.tr,
                            style: TextStyle(fontSize: 10, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text('notification_description'.tr),
                  value: controller.enableNotifications.value,
                  onChanged: (value) => controller.toggleNotifications(value),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              Obx(
                () => SwitchListTile(
                  title: Text(
                    'auto_connect'.tr,
                    style: Get.textTheme.titleMedium,
                  ),
                  subtitle: Text('auto_connect_description'.tr),
                  value: controller.enableAutoConnect.value,
                  onChanged: (value) => controller.toggleAutoConnect(value),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'about_app'.tr, icon: Icons.info_outline),
        _buildCard(
          context,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Get.theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SvgPicture.asset(
                    Assets.imagesLogoWhite,
                    colorFilter: ColorFilter.mode(
                      Get.theme.colorScheme.primary,
                      BlendMode.srcIn,
                    ),
                    semanticsLabel: 'Linqora logo',
                  ),
                ),
                title: const Text(
                  appName,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'app_version_text'.trParams({
                    'version': controller.appVersion.value,
                  }),
                ),
              ),

              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('docs'.tr, style: Get.textTheme.titleMedium),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => launchUrlHandler(docs),
              ),

              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('license'.tr, style: Get.textTheme.titleMedium),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => {},
              ),

              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'privacy_police'.tr,
                  style: Get.textTheme.titleMedium,
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => launchUrlHandler(privacy),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
