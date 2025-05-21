class AppLogger {
  // Прапорець для визначення, чи виводити логи
  static bool _isDebug = false;

  // Ініціалізація логера
  static void init({bool isDebug = false}) {
    _isDebug = isDebug;
    log('Logger initialized, debug mode: $_isDebug');
  }

  // Головний метод логування
  static void log(
    String message, {
    String module = 'App',
    LogLevel level = LogLevel.info,
  }) {
    if (!_isDebug && level != LogLevel.error) {
      return;
    }

    final DateTime now = DateTime.now();
    final String formattedTime =
        '${now.hour}:${now.minute}:${now.second}.${now.millisecond}';
    final String levelStr = level.toString().split('.').last.toUpperCase();

    print('[$formattedTime][$levelStr][$module] $message');
  }

  // Скорочені методи для різних рівнів логування
  static void debug(String message, {String module = 'App'}) {
    log(message, module: module, level: LogLevel.debug);
  }

  static void info(String message, {String module = 'App'}) {
    log(message, module: module, level: LogLevel.info);
  }

  static void warning(String message, {String module = 'App'}) {
    log(message, module: module, level: LogLevel.warning);
  }

  static void error(String message, {String module = 'App', Object? error}) {
    final errorMsg = error != null ? '$message | Error: $error' : message;
    log(errorMsg, module: module, level: LogLevel.error);
  }
}

// Рівні логування
enum LogLevel { debug, info, warning, error }
