import 'dart:convert';

/// Model representing system information for authentication
class AuthInformation {
  final String os;
  final String hostname;
  final int cpuModel; // Number of CPU cores
  final double virtualMemoryTotal; // Changed to double to match the 33.53 value

  AuthInformation({
    required this.os,
    required this.hostname,
    required this.cpuModel,
    required this.virtualMemoryTotal,
  });

  /// Convert the model to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'os': os,
      'hostname': hostname,
      'cpuModel': cpuModel,
      'virtualMemoryTotal': virtualMemoryTotal,
    };
  }

  /// Create an instance from a JSON map
  factory AuthInformation.fromJson(Map<String, dynamic> json) {
    return AuthInformation(
      os: json['os'] as String,
      hostname: json['hostname'] as String,
      cpuModel: json['cpuModel'] as int,
      virtualMemoryTotal: (json['virtualMemoryTotal'] is int)
          ? (json['virtualMemoryTotal'] as int).toDouble()
          : json['virtualMemoryTotal'] as double,
    );
  }

  @override
  String toString() {
    return 'OS: $os, Hostname: $hostname, CPU Cores: $cpuModel, Memory: ${virtualMemoryTotal}GB';
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
      'authInfomation': authInformation.toJson(), // Keep the original spelling in the output
    };
  }

  /// Create an instance from a JSON map
  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      type: json['type'] as String, // Changed from 'Type' to 'type'
      success: json['success'] as bool, // Changed from 'Success' to 'success'
      authInformation: AuthInformation.fromJson(json['authInfomation'] as Map<String, dynamic>), // Changed from 'AuthInfomation' to 'authInfomation'
    );
  }

  /// Convert the model to a JSON string
  String toJsonString() {
    return jsonEncode(toJson());
  }
}