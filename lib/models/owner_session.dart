class OwnerSession {
  final String stationId;
  final String ownerPhone;
  final String sessionToken;
  final String stationName;

  const OwnerSession({
    required this.stationId,
    required this.ownerPhone,
    required this.sessionToken,
    required this.stationName,
  });

  Map<String, dynamic> toOwnerData() => {
    'station_id': stationId,
    'owner_phone': ownerPhone,
    'session_token': sessionToken,
    'station_name': stationName,
  };
}
