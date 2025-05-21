import '../../core/utils/auth_response_handler.dart';

class AuthData {
  final bool success;
  final int code;
  final String message;

  AuthData({required this.success, required this.code, required this.message});

  factory AuthData.fromJson(Map<String, dynamic> json) {
    return AuthData(
      success: json['success'] as bool,
      code: json['code'] as int,
      message: json['message'] as String,
    );
  }

  /// Returns localized error message
  String get localMessage => AuthResponseHandler.getAuthMessage(code);

  /// Returns original message from server
  String get trueMessage => message;

  /// Checks if authorization is successful
  bool get isAuthorized => success && AuthResponseHandler.isSuccessCode(code);

  /// Checks if authorization is pending
  bool get isPending => AuthResponseHandler.isPendingCode(code);
}
