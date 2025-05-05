class CPUMetrics {
  final double temperature;
  final double loadPercent;
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
      temperature: json['temperature'] as double,
      loadPercent: json['loadPercent'] as double,
      processes: json['processes'] as int,
      threads: json['threads'] as int,
    );
  }
}

class RAMMetrics {
  final double usage;
  final double loadPercent;

  RAMMetrics({
    required this.usage,
    required this.loadPercent,
  });

  factory RAMMetrics.fromJson(Map<String, dynamic> json) {
    return RAMMetrics(
      usage: json['usage'] as double,
      loadPercent: json['loadPercent'] as double,
    );
  }
}