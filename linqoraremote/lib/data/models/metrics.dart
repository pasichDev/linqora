class CPUMetrics {
  final int temperature;
  final int loadPercent;
  final int processes;
  final int threads;

  CPUMetrics({
    required this.temperature,
    required this.loadPercent,
    required this.processes,
    required this.threads,
  });

  factory CPUMetrics.fromJson(Map<String, dynamic> json) {
    return CPUMetrics(
      temperature: json['temperature'] as int,
      loadPercent: json['loadPercent'] as int,
      processes: json['processes'] as int,
      threads: json['threads'] as int,
    );
  }
}

class RAMMetrics {
  final double usage;
  final int loadPercent;

  RAMMetrics({
    required this.usage,
    required this.loadPercent,
  });

  factory RAMMetrics.fromJson(Map<String, dynamic> json) {
    return RAMMetrics(
      usage: json['usage'] as double,
      loadPercent: json['loadPercent'] as int,
    );
  }
}