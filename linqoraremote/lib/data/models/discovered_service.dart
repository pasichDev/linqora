class DiscoveredService {
  final String name;
  final String? address;
  final String? port;  // Added port field

  DiscoveredService({
    required this.name,
    this.address,
    this.port,   // Include port in constructor
  });
}