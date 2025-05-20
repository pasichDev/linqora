class MdnsDevice {
  final String name;
  final String address;
  final String port;
  final bool supportsTLS;

  MdnsDevice({
    required this.name,
    required this.address,
    required this.port,
    required this.supportsTLS,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'port': port,
      'supportsTLS': supportsTLS,
    };
  }

  factory MdnsDevice.fromJson(Map<String, dynamic> json) {
    return MdnsDevice(
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      port: json['port'] ?? '',
      supportsTLS: json['supportsTLS'] ?? false,
    );
  }
}
