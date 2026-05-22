class ServiceModel {
  final String id;
  final String name;
  final int price;
  final int? durationMinutes;

  ServiceModel({
    required this.id,
    required this.name,
    required this.price,
    this.durationMinutes,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      price: json['price'] != null ? (json['price'] as num).toInt() : 0,
      durationMinutes: json['duration_minutes'] != null ? (json['duration_minutes'] as num).toInt() : null,
    );
  }
}
