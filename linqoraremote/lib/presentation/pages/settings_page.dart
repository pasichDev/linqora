import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:linqoraremote/core/constants/names.dart';
import 'package:linqoraremote/presentation/controllers/settings_controller.dart';
import 'package:linqoraremote/presentation/widgets/settings/sponsor_card.dart';
import 'package:linqoraremote/core/themes/lin_styles.dart';
import 'package:linqoraremote/presentation/widgets/animated_aurora_background.dart';

import '../../core/constants/urls.dart';
import '../../core/utils/lauch_url.dart';
import '../../generated/assets.dart';
import '../widgets/settings/section_header.dart';

class SettingsPage extends GetView<SettingsController> {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedAuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            "settings".tr,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24),
          ),
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Get.back(),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
          children: [
            const SponsorCard().animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),
            const SizedBox(height: 24),
            _buildThemeSection(context).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.1),
            const SizedBox(height: 24),
            _buildConnectionSection(context).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.1),
            const SizedBox(height: 24),
            _buildAboutSection(context).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideY(begin: 0.1),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassSection(BuildContext context, {required Widget child}) {
    return LinStyles.glassMorphism(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: child,
      ),
    );
  }

  Widget _buildThemeSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'design'.tr, icon: Icons.palette_rounded),
        const SizedBox(height: 12),
        _buildGlassSection(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'app_theme'.tr,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 20),
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
          Icons.settings_suggest_rounded,
          controller.themeMode.value == ThemeMode.system,
          () => controller.saveThemeMode(ThemeMode.system),
        ),
        _buildThemeOption(
          context,
          'theme_set_light'.tr,
          Icons.light_mode_rounded,
          controller.themeMode.value == ThemeMode.light,
          () => controller.saveThemeMode(ThemeMode.light),
        ),
        _buildThemeOption(
          context,
          'theme_set_dark'.tr,
          Icons.dark_mode_rounded,
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
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: MediaQuery.of(context).size.width * 0.25,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected ? colorScheme.primary.withOpacity(0.15) : Colors.white.withOpacity(0.05),
          border: Border.all(
            color: isSelected ? colorScheme.primary : Colors.white.withOpacity(0.1),
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: -5,
                  )
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? colorScheme.primary : Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? colorScheme.primary : Colors.white.withOpacity(0.7),
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
        SectionHeader(title: 'connecting'.tr, icon: Icons.bolt_rounded),
        const SizedBox(height: 12),
        _buildGlassSection(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Obx(
                () => _buildSwitchTile(
                  context,
                  title: 'notification'.tr,
                  subtitle: 'notification_description'.tr,
                  value: controller.enableNotifications.value,
                  onChanged: (value) => controller.toggleNotifications(value),
                  showBadge: !controller.notificationPermissionGranted.value && controller.enableNotifications.value,
                ),
              ),
              const Divider(height: 32, color: Colors.white10),
              Obx(
                () => _buildSwitchTile(
                  context,
                  title: 'auto_connect'.tr,
                  subtitle: 'auto_connect_description'.tr,
                  value: controller.enableAutoConnect.value,
                  onChanged: (value) => controller.toggleAutoConnect(value),
                ),
              ),
              const Divider(height: 32, color: Colors.white10),
              Obx(
                () => _buildSwitchTile(
                  context,
                  title: 'allow_self_signed'.tr,
                  subtitle: 'allow_self_signed_description'.tr,
                  value: controller.allowSelfSigned.value,
                  onChanged: (value) => controller.toggleAllowSelfSigned(value),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool showBadge = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  if (showBadge) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.5)),
                      ),
                      child: Text(
                        'required_permission'.tr,
                        style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5)),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'about_app'.tr, icon: Icons.auto_awesome_rounded),
        const SizedBox(height: 12),
        _buildGlassSection(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SvgPicture.asset(
                      Assets.imagesLogoWhite,
                      colorFilter: ColorFilter.mode(
                        Theme.of(context).colorScheme.primary,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          appName,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1),
                        ),
                        Text(
                          'app_version_text'.trParams({'version': controller.appVersion.value}),
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildListTile(
                context,
                title: 'docs'.tr,
                icon: Icons.description_rounded,
                onTap: () => launchUrlHandler(docs),
              ),
              const Divider(height: 1, color: Colors.white10),
              _buildListTile(
                context,
                title: 'license'.tr,
                icon: Icons.gavel_rounded,
                onTap: () {},
              ),
              const Divider(height: 1, color: Colors.white10),
              _buildListTile(
                context,
                title: 'privacy_police'.tr,
                icon: Icons.privacy_tip_rounded,
                onTap: () => launchUrlHandler(privacy),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.white.withOpacity(0.7), size: 22),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white.withOpacity(0.3)),
      onTap: onTap,
    );
  }
}
