class DiscoveredService {
  final String name;
  final String? address;
  final String? port;
  final String? authCode;
  final bool supportsTLS;

  DiscoveredService({
    required this.name,
    this.address,
    this.port,
    this.authCode,
    this.supportsTLS = false,
  });

  DiscoveredService copyWith({
    String? name,
    String? address,
    String? port,
    String? authCode,
    bool? supportsTLS,
  }) {
    return DiscoveredService(
      name: name ?? this.name,
      address: address ?? this.address,
      port: port ?? this.port,
      authCode: authCode ?? this.authCode,
      supportsTLS: supportsTLS ?? this.supportsTLS,
    );
  }
}
