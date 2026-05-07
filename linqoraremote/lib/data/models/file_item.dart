class FileItem {
  final String name;
  final int size;
  final bool isDir;
  final DateTime modTime;

  const FileItem({
    required this.name,
    required this.size,
    required this.isDir,
    required this.modTime,
  });

  factory FileItem.fromJson(Map<String, dynamic> json) {
    return FileItem(
      name: json['name'] as String,
      size: (json['size'] as num).toInt(),
      isDir: json['is_dir'] as bool,
      modTime: DateTime.parse(json['mod_time'] as String),
    );
  }

  String get formattedSize {
    if (isDir) return '';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
