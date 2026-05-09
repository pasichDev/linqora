import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:get_storage/get_storage.dart';
import '../../core/constants/settings.dart';

/// Synchronous TOFU pinning — caller supplies the trust-prompt callbacks.
/// [onFirstPin]: called when there is no stored pin yet; return true to accept.
/// [onMismatch]: called when the stored pin does not match; return true to re-pin.
class CertificateService {
  static const _prefix = 'cert_pin_';
  static String _key(String host) => '$_prefix$host';

  /// Plug in a UI-prompt function before connecting.
  static bool Function(String host, String fingerprint)? onFirstPin;
  static bool Function(String host, String storedFp, String newFp)? onMismatch;

  static bool verifyOrPin(X509Certificate cert, String host) {
    final storage = GetStorage(SettingsConst.kSettings);
    final key = _key(host);
    final fingerprint = _fingerprint(cert);
    final pinned = storage.read<String>(key);

    if (pinned == null || pinned.isEmpty) {
      final accept = onFirstPin?.call(host, fingerprint) ?? true;
      if (accept) storage.write(key, fingerprint);
      return accept;
    }

    if (pinned == fingerprint) return true;

    final repin = onMismatch?.call(host, pinned, fingerprint) ?? false;
    if (repin) storage.write(key, fingerprint);
    return repin;
  }

  static Future<void> clearPin(String host) async {
    await GetStorage(SettingsConst.kSettings).remove(_key(host));
  }

  static String? pinnedFingerprint(String host) =>
      GetStorage(SettingsConst.kSettings).read<String>(_key(host));

  static String _fingerprint(X509Certificate cert) =>
      sha256.convert(cert.der).toString();

  static String shortFingerprint(String fullHex) {
    if (fullHex.length < 16) return fullHex;
    return '${fullHex.substring(0, 16)}…${fullHex.substring(fullHex.length - 16)}';
  }
}
