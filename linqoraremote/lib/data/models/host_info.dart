class BaseSystemInfo {
  final String os;
  final String hostname;
  final bool su;
  final String ip;
  final bool supportsTLS;

  BaseSystemInfo({
    required this.os,
    required this.hostname,
    required this.su,
    this.ip = '',
    this.supportsTLS = false,
  });

  factory BaseSystemInfo.fromJson(Map<String, dynamic> json) {
    return BaseSystemInfo(
      os: json['os'] ?? 'Unknown OS',
      hostname: json['hostname'] ?? 'Unknown Host',
      su: json['su'] ?? false,
      ip: json['ip'] ?? '',
      supportsTLS: json['supportsTLS'] ?? false,
    );
  }
}

class CPUInfo {
  final String model;
  final int physicalCores;
  final int logicalCores;
  final double frequency;

  CPUInfo({
    this.model = 'Unknown',
    this.physicalCores = 0,
    this.logicalCores = 0,
    this.frequency = 0.0,
  });

  factory CPUInfo.fromJson(Map<String, dynamic> json) {
    return CPUInfo(
      model: json['Model'] ?? 'Unknown',
      physicalCores: json['PhysicalCores'] ?? 0,
      logicalCores: json['LogicalCores'] ?? 0,
      frequency: (json['Frequency'] ?? 0.0).toDouble(),
    );
  }
}

class RAMInfo {
  final String type;
  final int frequency;
  final int slots;
  final double used;
  final double total;

  double get free => total - used;
  double get usagePercentage => total > 0 ? (used / total * 100) : 0;

  RAMInfo({
    this.type = 'Unknown',
    this.frequency = 0,
    this.slots = 0,
    this.used = 0.0,
    this.total = 0.0,
  });

  factory RAMInfo.fromJson(Map<String, dynamic> json) {
    return RAMInfo(
      type: json['Type'] ?? 'Unknown',
      frequency: (json['Frequency'] ?? 0).toInt(),
      slots: (json['Slots'] ?? 0).toInt(),
      used: (json['Used'] ?? 0.0).toDouble(),
      total: (json['Total'] ?? 0.0).toDouble(),
    );
  }
}

class GPUInfo {
  final String model;
  final int memory;

  GPUInfo({this.model = 'Unknown', this.memory = 0});

  factory GPUInfo.fromJson(Map<String, dynamic> json) {
    return GPUInfo(
      model: json['Model'] ?? 'Unknown',
      memory: (json['Memory'] ?? 0).toInt(),
    );
  }
}

class DiskInfo {
  final String name;
  final double total;
  final double free;
  final double used;
  final String mountPath;
  final String fileSystem;

  double get usagePercentage => total > 0 ? (used / total * 100) : 0;

  DiskInfo({
    required this.name,
    required this.total,
    required this.free,
    required this.used,
    required this.mountPath,
    required this.fileSystem,
  });

  factory DiskInfo.fromJson(Map<String, dynamic> json) {
    return DiskInfo(
      name: json['name'] ?? 'Unknown',
      total: (json['total'] ?? 0.0).toDouble(),
      free: (json['free'] ?? 0.0).toDouble(),
      used: (json['used'] ?? 0.0).toDouble(),
      mountPath: json['mountPath'] ?? '',
      fileSystem: json['fileSystem'] ?? '',
    );
  }
}

class HostSystemInfo {
  final BaseSystemInfo baseInfo;
  final CPUInfo cpu;
  final RAMInfo ram;
  final GPUInfo gpu;
  final List<DiskInfo> disks;

  HostSystemInfo({
    required this.baseInfo,
    required this.cpu,
    required this.ram,
    required this.gpu,
    this.disks = const [],
  });

  factory HostSystemInfo.fromJson(Map<String, dynamic> json) {
    List<DiskInfo> disks = [];
    if (json['disks'] != null) {
      disks =
          (json['disks'] as List)
              .map((diskJson) => DiskInfo.fromJson(diskJson))
              .toList();
    }

    return HostSystemInfo(
      baseInfo: BaseSystemInfo.fromJson(json),
      cpu: CPUInfo.fromJson(json['cpu'] ?? {}),
      ram: RAMInfo.fromJson(json['ram'] ?? {}),
      gpu: GPUInfo.fromJson(json['gpu'] ?? {}),
      disks: disks,
    );
  }

  String get os => baseInfo.os;
  String get hostname => baseInfo.hostname;
}
