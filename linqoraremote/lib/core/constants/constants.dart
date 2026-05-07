import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';

import 'settings.dart';

/// Returns whether self-signed TLS certificates are allowed.
///
/// This is a runtime value stored in [GetStorage] (default: **false**).
/// Unlike the previous compile-time `const bool allowSelfSigned = true`,
/// this can be toggled from the Settings screen without recompiling the app.
///
/// SECURITY: Keep this false in production. Only enable for development/testing
/// environments where a trusted CA certificate cannot be deployed.
bool get allowSelfSigned =>
    GetStorage(SettingsConst.kSettings)
        .read<bool>(SettingsConst.kAllowSelfSigned) ??
    false;

/// Controls whether to display error messages for superuser (SU) operations.
///
/// In debug mode errors are suppressed; in release mode they are shown.
const bool showErrorSu = !kDebugMode;

/// Maximum number of missed pings before the connection is considered lost.
const int maxMissedPings = 4;
