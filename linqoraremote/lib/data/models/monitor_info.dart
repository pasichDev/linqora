class MonitorInfo {
  final String id;
  final String name;
  final bool isPrimary;
  final int width;
  final int height;
  final int refreshRate;
  final int x;
  final int y;

  const MonitorInfo({
    required this.id,
    required this.name,
    required this.isPrimary,
    required this.width,
    required this.height,
    required this.refreshRate,
    required this.x,
    required this.y,
  });

  factory MonitorInfo.fromJson(Map<String, dynamic> json) {
    return MonitorInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      isPrimary: json['is_primary'] as bool,
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
      refreshRate: (json['refresh_rate'] as num).toInt(),
      x: (json['x'] as num).toInt(),
      y: (json['y'] as num).toInt(),
    );
  }

  String get resolution => '${width}×$height @ ${refreshRate}Hz';
}
