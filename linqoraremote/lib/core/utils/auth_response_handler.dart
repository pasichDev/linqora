import 'package:get/get.dart';

/// Authorization status codes
class AuthStatusCode {
  static const int notAuthorized = 1; // Device not authorized
  static const int authorized = 100; // Device authorized
  static const int approved = 101; // Authorization approved
  static const int pending = 200; // Waiting for authorization
  static const int rejected = 400; // Authorization rejected
  static const int invalidFormat = 401; // Error: invalid request format
  static const int missingDeviceID = 402; // Error: device ID is missing
  static const int timeout = 500; // Authorization timeout
  static const int requestFailed = 501; // Authorization request error
  static const int unsupportedVersion = 502; // Error: outdated client version
}

/// Class for handling authorization responses
class AuthResponseHandler {
  static String getAuthMessage(int code) {
    final authMessages = {
      AuthStatusCode.notAuthorized: 'auth_not_authorized'.tr,
      AuthStatusCode.authorized: 'auth_authorized'.tr,
      AuthStatusCode.approved: 'auth_approved'.tr,
      AuthStatusCode.rejected: 'auth_rejected'.tr,
      AuthStatusCode.pending: 'auth_pending'.tr,
      AuthStatusCode.timeout: 'auth_timeout'.tr,
      AuthStatusCode.invalidFormat: 'auth_invalid_format'.tr,
      AuthStatusCode.missingDeviceID: 'auth_missing_device_id'.tr,
      AuthStatusCode.requestFailed: 'auth_request_failed'.tr,
      AuthStatusCode.unsupportedVersion: 'auth_unsupported_version'.tr,
    };


    return authMessages[code] ?? 'Unknown authorization error';
  }

  /// Checks if authorization is successful based on code
  static bool isSuccessCode(int code) {
    return code == AuthStatusCode.authorized || code == AuthStatusCode.approved;
  }

  /// Checks if authorization is pending
  static bool isPendingCode(int code) {
    return code == AuthStatusCode.pending;
  }
}
