
import 'dart:convert';

/// Model representing system information for authentication
class AuthInformation {
  final String os;
  final String hostname;
  final int cpuModel; // Number of CPU cores
  final int virtualMemoryTotal;

  AuthInformation({
    required this.os,
    required this.hostname,
    required this.cpuModel,
    required this.virtualMemoryTotal,
  });

  /// Convert the model to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'OS': os,
      'Hostname': hostname,
      'CpuModel': cpuModel,
      'VirtualMemoryTotal': virtualMemoryTotal,
    };
  }

  /// Create an instance from a JSON map
  factory AuthInformation.fromJson(Map<String, dynamic> json) {
    return AuthInformation(
      os: json['OS'] as String,
      hostname: json['Hostname'] as String,
      cpuModel: json['CpuModel'] as int,
      virtualMemoryTotal: json['VirtualMemoryTotal'] as int,
    );
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
      'Type': type,
      'Success': success,
      'AuthInfomation': authInformation.toJson(),
    };
  }

  /// Create an instance from a JSON map
  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      type: json['Type'] as String,
      success: json['Success'] as bool,
      authInformation: AuthInformation.fromJson(json['AuthInfomation'] as Map<String, dynamic>),
    );
  }

  /// Convert the model to a JSON string
  String toJsonString() {
    return jsonEncode(toJson());
  }
}
