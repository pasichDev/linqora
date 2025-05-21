/// A utility class for logging messages in the application.
///
/// This logger provides methods for logging messages in both debug and release modes.
/// It also allows initialization with a debug mode flag to control logging behavior.
class AppLogger {
  /// A private flag indicating whether the logger is in debug mode.
  static bool _isDebug = true;

  /// Initializes the logger with the specified debug mode.
  ///
  /// - **Parameters**:
  ///   - `isDebug` (`bool`): A flag to enable or disable debug mode. Defaults to `true`.
  static void init({bool isDebug = true}) {
    _isDebug = isDebug;
    _logInternal('Logger initialized, debug mode: $_isDebug', level: 'INIT');
  }

  /// Logs a debug message if the logger is in debug mode.
  ///
  /// - **Parameters**:
  ///   - `message` (`String`): The message to log.
  ///   - `module` (`String`): The module name associated with the log. Defaults to `'App'`.
  static void debug(String message, {String module = 'App'}) {
    if (_isDebug) {
      _logInternal(message, module: module, level: 'DEBUG');
    }
  }

  /// Logs a release message regardless of the debug mode.
  ///
  /// - **Parameters**:
  ///   - `message` (`String`): The message to log.
  ///   - `module` (`String`): The module name associated with the log. Defaults to `'App'`.
  static void release(String message, {String module = 'App'}) {
    _logInternal(message, module: module, level: 'RELEASE');
  }

  /// A private method for logging messages with a specific level and module.
  ///
  /// - **Parameters**:
  ///   - `message` (`String`): The message to log.
  ///   - `module` (`String`): The module name associated with the log. Defaults to `'App'`.
  static void _logInternal(
    String message, {
    String module = 'App',
    String level = 'LOG',
  }) {
    print('[$module] $message');
  }
}
