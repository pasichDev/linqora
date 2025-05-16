/// Formats a given time in seconds into a string representation of minutes and seconds.
///
/// The format of the returned string is `MM:SS`, where:
/// - `MM` is the number of minutes (calculated by integer division of seconds by 60).
/// - `SS` is the remaining seconds, padded with a leading zero if necessary.
///
/// Example:
/// ```dart
/// formatTimeTrack(125); // Returns "2:05"
/// ```
///
/// @param seconds The total time in seconds to be formatted.
/// @return A string representing the formatted time in `MM:SS` format.
String formatTimeTrack(int seconds) {
  final minutes = seconds ~/ 60;
  final remainingSeconds = seconds % 60;
  return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
}