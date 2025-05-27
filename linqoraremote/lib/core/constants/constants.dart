import 'package:flutter/foundation.dart';

/// A constant that determines whether self-signed certificates are allowed for SSL connections.
///
/// - **Purpose**: This is useful for development or testing environments where self-signed certificates
///   might be used.
/// - **Security Note**: It is strongly recommended to set this to `false` in production environments
///   to avoid potential security vulnerabilities.
///
/// **Default Value**: `true`
const bool allowSelfSigned = true;

/// A constant that controls whether to display error messages for superuser (SU) operations.
///
/// - **Behavior**:
///   - When the app is in debug mode (`kDebugMode` is `true`), this constant is set to `false`,
///     meaning error messages for SU operations are not shown.
///   - In non-debug (release) mode, this constant is set to `true`, enabling error messages.
///
/// **Default Value**: `!kDebugMode`
const bool showErrorSu = !kDebugMode;

/// The maximum number of missed pings allowed before considering the connection lost.
///
/// **Default Value**: `2`
const int maxMissedPings = 4;
