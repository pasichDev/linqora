import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:get_storage/get_storage.dart';

import '../../core/constants/settings.dart';

/// TOFU (Trust On First Use) certificate pinning for TLS connections.
///
/// On the first connection to a host the server's certificate fingerprint is
/// stored locally.  Subsequent connections verify the fingerprint matches.
/// This catches certificate swaps on the local network (e.g. MITM via ARP
/// spoofing) even when using self-signed certificates.
///
/// Fingerprints are stored under [SettingsConst.kSettings] in GetStorage.
/// The storage is not encrypted, but cert fingerprints are public values so
/// confidentiality is not required — only integrity matters.
class CertificateService {
  static const _prefix = 'cert_pin_';

  static String _key(String host) => '$_prefix$host';

  /// Called from [HttpClient.badCertificateCallback] for self-signed certs.
  ///
  /// Returns `true` (accept) when:
  /// - No fingerprint has been pinned yet → stores the fingerprint and accepts.
  /// - The stored fingerprint matches the presented certificate.
  ///
  /// Returns `false` (reject) when the fingerprint has changed since first use.
  static bool verifyOrPin(X509Certificate cert, String host) {
    final storage = GetStorage(SettingsConst.kSettings);
    final key = _key(host);
    final fingerprint = _fingerprint(cert);

    final pinned = storage.read<String>(key);
    if (pinned == null || pinned.isEmpty) {
      storage.write(key, fingerprint);
      return true;
    }

    return pinned == fingerprint;
  }

  /// Removes the stored pin for [host], allowing re-pinning on the next
  /// connection.  Call this when the user explicitly re-establishes trust
  /// (e.g., after the server regenerates its TLS certificate).
  static Future<void> clearPin(String host) async {
    final storage = GetStorage(SettingsConst.kSettings);
    await storage.remove(_key(host));
  }

  /// Returns the SHA-256 fingerprint of [cert]'s DER-encoded bytes as a
  /// lowercase hex string.
  static String _fingerprint(X509Certificate cert) {
    return sha256.convert(cert.der).toString();
  }

  /// Returns the stored fingerprint for [host], or `null` if none.
  static String? pinnedFingerprint(String host) {
    return GetStorage(SettingsConst.kSettings).read<String>(_key(host));
  }
}
