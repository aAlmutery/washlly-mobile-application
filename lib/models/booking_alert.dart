class BookingAlert {
  final String id;
  final String bookingId;
  final String stationType; // 'timeout', 'conflict', 'delay'
  final String title;
  final String message;
  final String severity; // 'info', 'warning', 'error'
  final DateTime createdAt;
  final bool resolved;
  final String? resolutionAction;

  BookingAlert({
    required this.id,
    required this.bookingId,
    required this.stationType,
    required this.title,
    required this.message,
    required this.severity,
    required this.createdAt,
    required this.resolved,
    this.resolutionAction,
  });

  factory BookingAlert.fromJson(Map<String, dynamic> json) {
    return BookingAlert(
      id: json['id'] ?? '',
      bookingId: json['booking_id'] ?? '',
      stationType: json['alert_type'] ?? 'info',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      severity: json['severity'] ?? 'info',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      resolved: json['resolved'] ?? false,
      resolutionAction: json['resolution_action'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'booking_id': bookingId,
        'alert_type': stationType,
        'title': title,
        'message': message,
        'severity': severity,
        'created_at': createdAt.toIso8601String(),
        'resolved': resolved,
        'resolution_action': resolutionAction,
      };
}

class TimeoutAlert {
  final String id;
  final String bookingId;
  final String customerPhone;
  final DateTime timeoutTime;
  final int minutesRemaining;
  final String status; // 'active', 'acknowledged', 'resolved'

  TimeoutAlert({
    required this.id,
    required this.bookingId,
    required this.customerPhone,
    required this.timeoutTime,
    required this.minutesRemaining,
    required this.status,
  });

  factory TimeoutAlert.fromJson(Map<String, dynamic> json) {
    final timeoutTime = json['timeout_time'] != null ? DateTime.parse(json['timeout_time'] as String) : DateTime.now();
    final minutesRemaining = timeoutTime.difference(DateTime.now()).inMinutes;

    return TimeoutAlert(
      id: json['id'] ?? '',
      bookingId: json['booking_id'] ?? '',
      customerPhone: json['customer_phone'] ?? '',
      timeoutTime: timeoutTime,
      minutesRemaining: minutesRemaining,
      status: json['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'booking_id': bookingId,
        'customer_phone': customerPhone,
        'timeout_time': timeoutTime.toIso8601String(),
        'status': status,
      };
}
