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

  /// List files/directories at a path.
  file_list,

  /// Read a file's content (base64 encoded).
  file_read,

  /// Write/create a file (content base64 encoded).
  file_write,

  /// Delete a file or directory.
  file_delete,

  /// List all connected monitors.
  monitor_list,

  /// Set monitor resolution and refresh rate.
  monitor_set_resolution,

  /// Set a monitor as the primary display.
  monitor_set_primary,

  /// Send a keystroke (with optional modifiers) to the host.
  keyboard,

  /// Write text to the host clipboard.
  clipboard_set,

  /// Host clipboard text pushed to the phone (server→client broadcast).
  clipboard_update,

  /// Sleep, wake, or set brightness of the host display.
  display_cmd,

  /// Request the list of running processes.
  process_list,

  /// Kill a process by PID.
  process_kill,

  /// Request the list of startup entries.
  startup_list,

  /// Enable or disable a startup entry by name.
  startup_set,

  /// Configure the battery alert threshold.
  battery_alert_config,

  /// Server-pushed notification: host battery is low.
  battery_alert,

  /// Type a string of text on the host (Unicode, up to 1000 chars).
  keyboard_type,

  /// Request platform capability flags from the host.
  platform_caps,
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
