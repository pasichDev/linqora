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

  // Go encodes float64 whole numbers without a decimal point (e.g. 45.0 → 45),
  // so Dart may parse them as int OR double depending on the value.
  // Casting via (num) handles both cases safely.
  factory CPUMetrics.fromJson(Map<String, dynamic> json) {
    return CPUMetrics(
      temperature: (json['temperature'] as num).toInt(),
      loadPercent: (json['loadPercent'] as num).toInt(),
      processes: (json['processes'] as num).toInt(),
      threads: (json['threads'] as num).toInt(),
    );
  }
}

class RAMMetrics {
  final double usage;
  final int loadPercent;

  RAMMetrics({required this.usage, required this.loadPercent});

  factory RAMMetrics.fromJson(Map<String, dynamic> json) {
    return RAMMetrics(
      usage: (json['usage'] as num).toDouble(),
      loadPercent: (json['loadPercent'] as num).toInt(),
    );
  }
}
