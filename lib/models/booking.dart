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
    // Support both Supabase REST join format (services:{name,price}, stations:{name})
    // and edge-function flat format (service_name, station_name, service_price / price).
    final servicesMap = json['services'] as Map?;
    final stationsMap = json['stations'] as Map?;

    String parseTime(dynamic raw) {
      final s = (raw as String?) ?? '00:00';
      // Postgres may return "HH:MM:SS" — keep only "HH:MM"
      return s.length > 5 ? s.substring(0, 5) : s;
    }

    return Booking(
      id: json['id'] as String,
      bookingNumber: json['booking_number'] as int? ?? 0,
      stationId: json['station_id'] as String? ?? '',
      serviceName: servicesMap?['name'] as String?
          ?? json['service_name'] as String?
          ?? '',
      stationName: stationsMap?['name'] as String?
          ?? json['station_name'] as String?
          ?? '',
      customerName: json['customer_name'] as String? ?? '',
      customerPhone: json['customer_phone'] as String? ?? '',
      bookingDate: json['booking_date'] as String? ?? '',
      bookingTime: parseTime(json['booking_time']),
      status: json['status'] as String? ?? 'pending',
      price: (servicesMap?['price'] as num?)?.toDouble()
          ?? (json['service_price'] as num?)?.toDouble()
          ?? (json['price'] as num?)?.toDouble(),
      customerRating: json['customer_rating'] as int?,
      ratedAt: json['rated_at'] != null ? DateTime.tryParse(json['rated_at'] as String) : null,
      proposedDate: json['proposed_date'] as String?,
      proposedTime: json['proposed_time'] != null
          ? parseTime(json['proposed_time'])
          : null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
