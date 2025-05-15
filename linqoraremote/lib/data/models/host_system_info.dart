class HostSystemInfo {
  final String os;
  final String hostname;
  final String cpuModel;
  final int virtualMemoryTotal;
  final int cpuPhysicalCores;
  final int cpuLogicalCores;
  final double cpuFrequency;
  final String ip;
  final bool supportsTLS;

  HostSystemInfo({
    required this.os,
    required this.hostname,
    this.cpuModel = 'Unknown',
    this.virtualMemoryTotal = 0,
    this.cpuPhysicalCores = 0,
    this.cpuLogicalCores = 0,
    this.cpuFrequency = 0.0,
    this.ip = '',
    this.supportsTLS = false,
  });

  factory HostSystemInfo.fromJson(Map<String, dynamic> json) {
    return HostSystemInfo(
      os: json['os'] ?? 'Unknown OS',
      hostname: json['hostname'] ?? 'Unknown Host',
      cpuModel: json['cpuModel'] ?? 'Unknown CPU',
      virtualMemoryTotal: (json['virtualMemoryTotal'] ?? 0).toInt(),
      cpuPhysicalCores: (json['physicalCores'] ?? 0).toInt(),
      cpuLogicalCores: (json['logicalCores'] ?? 0).toInt(),
      cpuFrequency: (json['cpuFrequency'] ?? 0.0).toDouble(),
      ip: json['ip'] ?? '',
      supportsTLS: json['supportsTLS'] ?? false,
    );
  }
}
