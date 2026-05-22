class Station {
  final String id;
  final String name;
  final String address;
  final String? detailedAddress;
  final double? latitude;
  final double? longitude;

  Station({
    required this.id,
    required this.name,
    required this.address,
    this.detailedAddress,
    this.latitude,
    this.longitude,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String? ?? '',
      detailedAddress: json['detailed_address'] as String?,
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
    );
  }
}
