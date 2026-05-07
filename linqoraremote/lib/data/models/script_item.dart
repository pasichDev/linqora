class ScriptItem {
  final String id;
  final String name;
  final String description;
  final String command;
  final List<String> args;
  final String? workDir;

  ScriptItem({
    required this.id,
    required this.name,
    required this.description,
    required this.command,
    this.args = const [],
    this.workDir,
  });

  factory ScriptItem.fromJson(Map<String, dynamic> json) {
    return ScriptItem(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      command: json['command'] as String? ?? '',
      args: (json['args'] as List?)?.map((e) => e as String).toList() ?? [],
      workDir: json['work_dir'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'command': command,
      'args': args,
      'work_dir': workDir,
    };
  }
}
