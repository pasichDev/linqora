/// A class containing constants for media-related actions.
///
/// These constants represent various media commands that can be used
/// to control media playback or retrieve media information.
class MediaActions {
  /// Command to toggle play/pause for media playback.
  static const int mediaPlayPause = 10;

  /// Command to skip to the next media track.
  static const int mediaNext = 12;

  /// Command to go back to the previous media track.
  static const int mediaPrevious = 13;

  /// Command to retrieve information about the current media.
  static const int mediaGetInfo = 14;
}

/// A class containing constants for audio-related actions.
///
/// These constants represent various commands to control audio settings
/// such as volume and mute state.
class AudioActions {
  /// Command to set the audio volume to a specific level.
  static const int setVolume = 0;

  /// Command to mute the audio.
  static const int mute = 1;

  /// Command to increase the audio volume.
  static const int increaseVolume = 2;

  /// Command to decrease the audio volume.
  static const int decreaseVolume = 3;
}
