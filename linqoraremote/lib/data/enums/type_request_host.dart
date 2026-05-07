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

  /// Challenge issued by the server for HMAC verification.
  auth_challenge,

  /// Client's HMAC response to a server challenge.
  auth_challenge_response,

  /// Mouse / touchpad control command.
  mouse,

  /// List all server-registered scripts.
  script_list,

  /// Add a new script.
  script_add,

  /// Update an existing script.
  script_update,

  /// Delete a script by id.
  script_delete,

  /// Execute a server-registered script by id.
  script_execute,

  /// Stop a running script by id.
  script_stop,

  /// Real-time output line from a running script.
  script_output,
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
