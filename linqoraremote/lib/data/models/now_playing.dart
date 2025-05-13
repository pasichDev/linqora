class NowPlaying {
  final String artist;
  final String title;
  final String album;
  final String application;
  final bool isPlaying;
  final int position;
  final int duration;
  final String stringPosition;
  final String stringDuration;

  double get progress => duration == 0 ? 0.0 : position / duration;

  NowPlaying({
    required this.artist,
    required this.title,
    required this.album,
    required this.application,
    required this.isPlaying,
    required this.position,
    required this.duration,
    this.stringDuration = "00:00",
    this.stringPosition = "00:00",
  });

  factory NowPlaying.fromJson(Map<String, dynamic> json) {
    return NowPlaying(
      artist: json['artist'] as String? ?? '',
      title: json['title'] as String? ?? '',
      album: json['album'] as String? ?? '',
      application: json['application'] as String? ?? '',
      isPlaying: json['isPlaying'] as bool? ?? false,
      position: json['position'] as int? ?? 0,
      duration: json['duration'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'artist': artist,
      'title': title,
      'album': album,
      'application': application,
      'isPlaying': isPlaying,
      'position': position,
      'duration': duration,
    };
  }

  NowPlaying copyWith({
    String? artist,
    String? title,
    String? album,
    String? application,
    bool? isPlaying,
    int? position,
    int? duration,
    String stringPosition = "00:00",
    String stringDuration = "00:00",
    bool isLoading = false,
  }) {
    return NowPlaying(
      artist: artist ?? this.artist,
      title: title ?? this.title,
      album: album ?? this.album,
      application: application ?? this.application,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      stringPosition: stringPosition,
      stringDuration: stringDuration,
    );
  }
}
