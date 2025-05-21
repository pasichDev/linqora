import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:getx_multilanguage_helper/getx_multilanguage_helper.dart';
import 'package:linqoraremote/core/themes/theme.dart';
import 'package:linqoraremote/presentation/controllers/settings_controller.dart';
import 'package:linqoraremote/routes/app_routes.dart';

import 'core/constants/names.dart';
import 'core/constants/settings.dart';
import 'core/utils/app_logger.dart';
import 'services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.init(isDebug: kDebugMode);
  try {
    await BackgroundConnectionService.initializeService();
  } catch (e) {
    debugPrint("Error initializing background service: $e");
  }

  await GetStorage.init(SettingsConst.kSettings);

  await loadTranslations();
  runApp(MyApp());
}

Future<void> loadTranslations() async {
  await Get.putAsync(() async {
    final deviceLocale = PlatformDispatcher.instance.locale;
    final deviceLanguageCode = deviceLocale.languageCode;
    final deviceCountryCode = deviceLocale.countryCode;

    final String deviceLocaleKey =
        '${deviceLanguageCode}_${deviceCountryCode?.toUpperCase() ?? deviceLanguageCode.toUpperCase()}';

    final availableLanguages = [
      LanguageModel(title: 'en'.tr, localeKey: 'en_EN'),
      LanguageModel(title: 'uk'.tr, localeKey: 'uk_UA'),
      LanguageModel(title: 'de'.tr, localeKey: 'de_DE'),
    ];

    final isDeviceLanguageSupported = availableLanguages.any(
      (lang) => lang.localeKey.toLowerCase() == deviceLocaleKey.toLowerCase(),
    );

    Locale initialLocale;

    if (isDeviceLanguageSupported) {
      final supportedLang = availableLanguages.firstWhere(
        (lang) => lang.localeKey.toLowerCase() == deviceLocaleKey.toLowerCase(),
      );
      final parts = supportedLang.localeKey.split('_');
      initialLocale = Locale(parts[0], parts[1]);
    } else {
      initialLocale = const Locale('en', 'EN');
    }

    return await GetxMultilanguageHelperController().init(
      config: GetxMultilanguageHelperConfiguration(
        translationPath: 'assets/languages/',
        languages: availableLanguages,
        defaultLocale: initialLocale,
        fallbackLocale: const Locale('en', 'EN'),
      ),
    );
  });
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final settingsController = Get.put(SettingsController());

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => GetMaterialApp(
        title: appName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: MaterialTheme.lightScheme(),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: MaterialTheme.darkScheme(),
        ),
        themeMode: settingsController.themeMode.value,
        initialRoute: AppRoutes.DEVICE_AUTH,
        getPages: AppRoutes().routes,
        defaultTransition: Transition.cupertino,
        translations: GetxMultilanguageHelperTranslation(),
        locale: GetxMultilanguageHelperTranslation.defaultLocale,
        fallbackLocale: GetxMultilanguageHelperTranslation.fallbackLocale,
      ),
    );
  }
}
