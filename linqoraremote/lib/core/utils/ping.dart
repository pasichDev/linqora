/// The maximum number of missed pings allowed before considering the connection lost.
///
/// **Default Value**: `2`
const int maxMissedPings = 2;

/// The interval (in seconds) between pings when the application is running in the background.
///
/// **Default Value**: `60`
const int backgroundPingInterval = 60;

/// The interval (in seconds) between pings when the application is active.
///
/// **Default Value**: `25`
const int activePingInterval = 25;

/// Returns the current ping interval as a `Duration` based on the application's state.
///
/// - **Parameters**:
///   - `isBackground` (`bool`): A flag indicating whether the application is in the background.
///     - `true`: Use the background ping interval.
///     - `false`: Use the active ping interval.
/// - **Returns**: A `Duration` object representing the appropriate ping interval.
///
/// **Example**:
/// ```dart
/// Duration interval = getCurrentPingInterval(true); // Returns 60 seconds as a Duration.
/// ```
Duration getCurrentPingInterval(bool isBackground) {
  return Duration(
    seconds: isBackground ? backgroundPingInterval : activePingInterval,
  );
}
