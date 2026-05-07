class ScriptExecuteResponse {
  final String id;
  final int exitCode;
  final String stdout;
  final String stderr;
  final int durationMs;

  ScriptExecuteResponse({
    required this.id,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.durationMs,
  });

  factory ScriptExecuteResponse.fromJson(Map<String, dynamic> json) {
    return ScriptExecuteResponse(
      id: json['id'] as String,
      exitCode: json['exit_code'] as int,
      stdout: json['stdout'] as String,
      stderr: json['stderr'] as String,
      durationMs: json['duration_ms'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exit_code': exitCode,
      'stdout': stdout,
      'stderr': stderr,
      'duration_ms': durationMs,
    };
  }
}
