/// An enumeration representing the different types of WebSocket messages.
///
/// This enum defines various message types that can be sent or received
/// during WebSocket communication.
enum TypeMessageWs {
  /// Authentication message type.
  auth,

  /// Message type for joining a room.
  join_room,

  /// Message type for leaving a room.
  leave_room,

  /// Message type for authentication response.
  auth_response,

  /// Message type indicating authentication is pending.
  auth_pending,

  /// Message type for authentication request.
  auth_request,

  /// Message type for media-related communication.
  media,

  /// Message type for sending metrics data.
  metrics,

  /// Message type for host information.
  host_info,

  /// Message type for authentication check.
  auth_check,

  /// Message type for power-related actions.
  power,
}

/// An extension on the `TypeMessageWs` enum to provide additional functionality.
extension TypeMessageWsExtension on TypeMessageWs {
  /// Retrieves the string value of the enum constant.
  ///
  /// - **Behavior**: Converts the enum constant to a string and extracts
  ///   the part after the dot (`.`), which represents the name of the constant.
  ///
  /// - **Returns**: A `String` containing the name of the enum constant.
  String get value {
    return toString().split('.').last;
  }
}
