// auth_response_handler.dart
// Обработчик ответов авторизации от Linqora Host Server

import 'package:linqoraremote/data/enums/type_messages_ws.dart';

/// Коды статусов авторизации
class AuthStatusCode {
  // Устройство не авторизовано
  static const int notAuthorized = 1;

  // Устройство авторизовано
  static const int authorized = 100;

  // Авторизация одобрена
  static const int approved = 101;

  // Ожидание авторизации
  static const int pending = 200;

  // Авторизация отклонена
  static const int rejected = 400;

  // Ошибка неверный формат запроса
  static const int invalidFormat = 401;

  // Ошибка отсутствует ID устройства
  static const int missingDeviceID = 402;

  // Истекло время ожидания авторизации
  static const int timeout = 500;

  // Ошибка запроса авторизации
  static const int requestFailed = 501;
}

/// Класс для обработки ответов авторизации
class AuthResponseHandler {
  /// Возвращает сообщение по коду статуса
  static String getAuthMessage(int code) {
    final messages = {
      AuthStatusCode.notAuthorized: 'Device not authorized',
      AuthStatusCode.authorized: 'Device authorized',
      AuthStatusCode.approved: 'Authorization approved',
      AuthStatusCode.rejected: 'Authorization rejected',
      AuthStatusCode.pending: 'Waiting for authorization',
      AuthStatusCode.timeout: 'Authorization timeout',
      AuthStatusCode.invalidFormat: 'Invalid authorization data format',
      AuthStatusCode.missingDeviceID: 'Device ID is missing',
      AuthStatusCode.requestFailed: 'Authorization request failed',
    };

    return messages[code] ?? 'Unknown authorization error';
  }

  /// Проверяет успешность авторизации по коду
  static bool isSuccessCode(int code) {
    return code == AuthStatusCode.authorized || code == AuthStatusCode.approved;
  }

  /// Проверяет, находится ли авторизация в ожидании
  static bool isPendingCode(int code) {
    return code == AuthStatusCode.pending;
  }
}

/// Модель для ответа авторизации
class AuthResponse {
  final String type;
  final bool success;
  final int codeResponse;
  final String data;
  final Map<String, dynamic>? extra;

  AuthResponse({
    required this.type,
    required this.success,
    required this.codeResponse,
    required this.data,
    this.extra,
  });

  /// Создает экземпляр из JSON
  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      type: json['type'] as String,
      success: json['success'] as bool,
      codeResponse: json['codeResponse'] as int,
      data: json['data'] as String,
      extra: json['extra'] as Map<String, dynamic>?,
    );
  }

  /// Возвращает локализованное сообщение об ошибке
  String get message => AuthResponseHandler.getAuthMessage(codeResponse);

  /// Проверяет успешность авторизации
  bool get isAuthorized =>
      success && AuthResponseHandler.isSuccessCode(codeResponse);

  /// Проверяет, находится ли авторизация в ожидании
  bool get isPending =>
      type == TypeMessageWs.auth_pending.value ||
      AuthResponseHandler.isPendingCode(codeResponse);
}
