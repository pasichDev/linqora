class DiscoveredService {
  final String id;
  final String name;
  final String address;
  final String port;
  final bool supportsTLS;
  final String? hostname;
  final String? osInfo;
  String? authToken;

  DiscoveredService({
    required this.id,
    required this.name,
    required this.address,
    required this.port,
    required this.supportsTLS,
    this.hostname,
    this.osInfo,
    this.authToken,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'port': port,
      'supportsTLS': supportsTLS,
      'hostname': hostname,
      'osInfo': osInfo,
      'authToken': authToken,
    };
  }

  factory DiscoveredService.fromJson(Map<String, dynamic> json) {
    return DiscoveredService(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      port: json['port'] ?? '',
      supportsTLS: json['supportsTLS'] ?? false,
      hostname: json['hostname'],
      osInfo: json['osInfo'],
      authToken: json['authToken'],
    );
  }
}