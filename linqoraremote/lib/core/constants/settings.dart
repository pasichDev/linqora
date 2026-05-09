/// WebSocket API version this build of the app supports.
/// Must match LinqoraHost/internal/version.API — increment both together on breaking changes.
const kApiVersion = 1;

class SettingsConst {
  static const kSettings = 'settings';
  static const kThemeMode = 'theme_mode';
  static const kEnableNotifications = 'enable_notifications';
  static const kEnableAutoConnect = 'enable_auto_connect';
  static const kLastConnect = 'last_connect';
  static const kShowHostInfo = 'show_host_info';

  /// When true the app accepts self-signed TLS certificates.
  /// Default false; toggle via Settings screen for dev/test environments only.
  static const kAllowSelfSigned = 'allow_self_signed';

  /// JSON list of recently connected MdnsDevice objects (max 5).
  static const kSavedHosts = 'saved_hosts';

  /// True after the user completes (or skips) the first-run onboarding.
  static const kOnboardingComplete = 'onboarding_complete';
}
