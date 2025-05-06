import 'dart:convert';

/// Model representing system information for authentication
class AuthInformation {
  final String os;
  final String hostname;
  final String cpuModel;
  final double cpuFrequency;
  final int cpuPhysicalCores;
  final int cpuLogicalCores;
  final double virtualMemoryTotal;

  AuthInformation({
    required this.os,
    required this.hostname,
    required this.cpuModel,
    required this.cpuFrequency,
    required this.cpuPhysicalCores,
    required this.cpuLogicalCores,
    required this.virtualMemoryTotal,
  });

  /// Convert the model to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'os': os,
      'hostname': hostname,
      'cpuModel': cpuModel,
      'cpuFrequency': cpuFrequency,
      'physicalCores': cpuPhysicalCores,
      'logicalCores': cpuLogicalCores,
      'virtualMemoryTotal': virtualMemoryTotal,
    };
  }

  /// Create an instance from a JSON map
  factory AuthInformation.fromJson(Map<String, dynamic> json) {
    return AuthInformation(
      os: json['os'] as String,
      hostname: json['hostname'] as String,
      cpuModel: json['cpuModel'] as String,
      cpuFrequency: json['cpuFrequency'] is int
          ? (json['cpuFrequency'] as int).toDouble()
          : json['cpuFrequency'] as double,
      cpuPhysicalCores: json['physicalCores'] as int,
      cpuLogicalCores: json['logicalCores'] as int,
      virtualMemoryTotal: json['virtualMemoryTotal'] is int
          ? (json['virtualMemoryTotal'] as int).toDouble()
          : json['virtualMemoryTotal'] as double,
    );
  }

  @override
  String toString() {
    return 'OS: $os, Hostname: $hostname, CPU: $cpuModel ($cpuFrequency MHz), '
        'Cores: $cpuPhysicalCores/$cpuLogicalCores, Memory: ${virtualMemoryTotal}GB';
  }
}

/// Authentication response model
class AuthResponse {
  final String type;
  final bool success;
  final AuthInformation authInformation;

  AuthResponse({
    required this.type,
    required this.success,
    required this.authInformation,
  });

  /// Convert the model to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'success': success,
      'authInfomation': authInformation.toJson(),
    };
  }

  /// Create an instance from a JSON map
  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      type: json['type'] as String,
      success: json['success'] as bool,
      authInformation: AuthInformation.fromJson(
        json['authInfomation'] as Map<String, dynamic>,
      ),
    );
  }

  /// Convert the model to a JSON string
  String toJsonString() {
    return jsonEncode(toJson());
  }
}
