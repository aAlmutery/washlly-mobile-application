class CustomerSession {
  final String customerPhone;
  final String customerName;
  final String sessionToken;
  final DateTime expiresAt;

  CustomerSession({
    required this.customerPhone,
    required this.customerName,
    required this.sessionToken,
    required this.expiresAt,
  });

  bool get isValid => DateTime.now().isBefore(expiresAt);

  factory CustomerSession.fromJson(Map<String, dynamic> json) {
    return CustomerSession(
      customerPhone: json['customer_phone'] as String,
      customerName: json['customer_name'] as String,
      sessionToken: json['session_token'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }
}
