class MediaCapabilities {
  final bool canControlVolume;
  final bool canControlMedia;
  final bool canGetMediaInfo;
  final int currentVolume;
  final bool isMuted;

  MediaCapabilities({
    this.canControlVolume = false,
    this.canControlMedia = false,
    this.canGetMediaInfo = false,
    this.currentVolume = 50,
    this.isMuted = false,
  });

  factory MediaCapabilities.fromJson(Map<String, dynamic> json) {
    return MediaCapabilities(
      canControlVolume: json['canControlVolume'] ?? false,
      canControlMedia: json['canControlMedia'] ?? false,
      canGetMediaInfo: json['canGetMediaInfo'] ?? false,
      currentVolume: json['currentVolume'] ?? 50,
      isMuted: json['isMuted'] ?? false,
    );
  }
}