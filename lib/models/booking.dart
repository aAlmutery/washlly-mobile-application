class Booking {
  final String id;
  final int bookingNumber;
  final String stationId;
  final String serviceName;
  final String stationName;
  final String customerName;
  final String customerPhone;
  final String bookingDate;
  final String bookingTime;
  final String status; // pending, pending_owner_approval, pending_customer_approval, confirmed, completed, cancelled
  final double? price;
  final int? customerRating;
  final DateTime? ratedAt;
  final String? proposedDate;
  final String? proposedTime;
  final DateTime createdAt;

  Booking({
    required this.id,
    required this.bookingNumber,
    required this.stationId,
    required this.serviceName,
    required this.stationName,
    required this.customerName,
    required this.customerPhone,
    required this.bookingDate,
    required this.bookingTime,
    required this.status,
    this.price,
    this.customerRating,
    this.ratedAt,
    this.proposedDate,
    this.proposedTime,
    required this.createdAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] as String,
      bookingNumber: json['booking_number'] as int,
      stationId: json['station_id'] as String,
      serviceName: (json['services'] as Map?)?['name'] as String? ?? 'Service',
      stationName: (json['stations'] as Map?)?['name'] as String? ?? 'Station',
      customerName: json['customer_name'] as String,
      customerPhone: json['customer_phone'] as String,
      bookingDate: json['booking_date'] as String,
      bookingTime: json['booking_time'] as String,
      status: json['status'] as String,
      price: ((json['services'] as Map?)?['price'] as num?)?.toDouble(),
      customerRating: json['customer_rating'] as int?,
      ratedAt: json['rated_at'] != null ? DateTime.parse(json['rated_at']) : null,
      proposedDate: json['proposed_date'] as String?,
      proposedTime: json['proposed_time'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
