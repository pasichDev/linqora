/// Коды статусов авторизации
class AuthStatusCode {
  static const int notAuthorized = 1; // Устройство не авторизовано
  static const int authorized = 100; // Устройство авторизовано
  static const int approved = 101; // Авторизация одобрена
  static const int pending = 200; // Ожидание авторизации
  static const int rejected = 400; // Авторизация отклонена
  static const int invalidFormat = 401; // Ошибка неверный формат запроса
  static const int missingDeviceID = 402; // Ошибка отсутствует ID устройства
  static const int timeout = 500; // Истекло время ожидания авторизации
  static const int requestFailed = 501; // Ошибка запроса авторизации
  static const int unsupportedVersion = 502; // Ошибка устаревшая версия клиента
}

/// Класс для обработки ответов авторизации
class AuthResponseHandler {
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
      AuthStatusCode.unsupportedVersion:
          'Client version is outdated and not supported',
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

class AuthData {
  final bool success;
  final int code;
  final String message;

  AuthData({required this.success, required this.code, required this.message});

  /// Создает экземпляр из JSON
  factory AuthData.fromJson(Map<String, dynamic> json) {
    return AuthData(
      success: json['success'] as bool,
      code: json['code'] as int,
      message: json['message'] as String,
    );
  }

  /// Возвращает локализованное сообщение об ошибке
  String get localMessage => AuthResponseHandler.getAuthMessage(code);

  /// Повертає типове повідомлення з серверу
  String get trueMessage => message;

  /// Проверяет успешность авторизации
  bool get isAuthorized => success && AuthResponseHandler.isSuccessCode(code);

  /// Проверяет, находится ли авторизация в ожидании
  bool get isPending => AuthResponseHandler.isPendingCode(code);
}
