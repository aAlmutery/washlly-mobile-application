class CustomerNotification {
  final String id;
  final String title;
  final String body;
  final String? referenceBookingId;
  final bool isRead;
  final DateTime createdAt;

  CustomerNotification({
    required this.id,
    required this.title,
    required this.body,
    this.referenceBookingId,
    required this.isRead,
    required this.createdAt,
  });

  factory CustomerNotification.fromJson(Map<String, dynamic> json) {
    return CustomerNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      referenceBookingId: json['reference_booking_id'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
