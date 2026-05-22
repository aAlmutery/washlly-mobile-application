import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/service_model.dart';
import '../models/station.dart';

class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();
  final SupabaseClient client = Supabase.instance.client;

  Future<List<Station>> fetchStations() async {
    final data = await client
        .from('stations')
        .select('id,name,address,detailed_address,latitude,longitude,is_active')
        .eq('is_active', true)
        .order('name');

    return (data as List<dynamic>)
        .map((item) => Station.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<ServiceModel>> fetchServices(String stationId) async {
    final data = await client
        .from('services')
        .select('id,name,price,duration_minutes')
        .eq('station_id', stationId)
        .eq('is_active', true)
        .order('sort_order');

    return (data as List<dynamic>)
        .map((item) => ServiceModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<String>> fetchServiceNames() async {
    final data = await client
        .from('services')
        .select('name')
        .eq('is_active', true)
        .order('name');

    return (data as List<dynamic>)
        .map((item) => (item as Map<String, dynamic>)['name'] as String)
        .toSet()
        .toList()
      ..sort();
  }

  Future<List<String>> fetchStationIdsByServiceName(String serviceName) async {
    final data = await client
        .from('services')
        .select('station_id')
        .eq('is_active', true)
        .eq('name', serviceName);

    return (data as List<dynamic>)
        .map((item) => (item as Map<String, dynamic>)['station_id'] as String)
        .toList();
  }

  Future<Map<String, dynamic>> ownerSelfRegister({
    required String ownerName,
    required String ownerPhone,
    String? email,
    required String password,
    int freeRequestsQuota = 20,
    required Map<String, dynamic> station,
    required List<Map<String, dynamic>> services,
  }) async {
    final response = await client.functions.invoke(
      'owner-self-register',
      body: {
        'owner_name': ownerName,
        'owner_phone': ownerPhone,
        'email': email,
        'password': password,
        'free_requests_quota': freeRequestsQuota,
        'station': station,
        'services': services,
      },
    );

    if (response.status >= 400) {
      throw Exception('Function error: ${response.status}');
    }

    return Map<String, dynamic>.from(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> ownerLoginLookup(String identifier) async {
    final response = await client.functions.invoke(
      'owner-login-lookup',
      body: {'identifier': identifier},
    );

    if (response.status >= 400) {
      throw Exception('Function error: ${response.status}');
    }

    return Map<String, dynamic>.from(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> spinBookingDiscount({
    required String stationId,
    required String serviceId,
    required String bookingDate,
    required String bookingTime,
    required String customerPhone,
  }) async {
    final response = await client.functions.invoke(
      'spin-booking-discount',
      body: {
        'station_id': stationId,
        'service_id': serviceId,
        'booking_date': bookingDate,
        'booking_time': bookingTime,
        'customer_phone': customerPhone,
      },
    );

    if (response.status >= 400) {
      throw Exception('Function error: ${response.status}');
    }

    return Map<String, dynamic>.from(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> createMapBooking({
    required String stationId,
    required String serviceId,
    required String customerName,
    required String customerPhone,
    required String bookingDate,
    required String bookingTime,
    required int spinDiscountPercent,
    required String spinToken,
    String language = 'ar',
  }) async {
    final response = await client.functions.invoke(
      'create-map-booking',
      body: {
        'station_id': stationId,
        'service_id': serviceId,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'booking_date': bookingDate,
        'booking_time': bookingTime,
        'spin_discount_percent': spinDiscountPercent,
        'spin_token': spinToken,
        'language': language,
      },
    );

    if (response.status >= 400) {
      throw Exception('Function error: ${response.status}');
    }

    return Map<String, dynamic>.from(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> createQuickBooking({
    required String customerName,
    required String customerPhone,
    required String bookingDate,
    required String bookingTime,
    required String serviceKind,
    required double customerLat,
    required double customerLng,
    List<String> excludeStationIds = const [],
    String language = 'ar',
  }) async {
    final response = await client.functions.invoke(
      'create-quick-booking',
      body: {
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'booking_date': bookingDate,
        'booking_time': bookingTime,
        'service_kind': serviceKind,
        'language': language,
        'customer_lat': customerLat,
        'customer_lng': customerLng,
        'exclude_station_ids': excludeStationIds,
      },
    );

    if (response.status >= 400) {
      throw Exception('Function error: ${response.status}');
    }

    return Map<String, dynamic>.from(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> cancelMapBooking({
    required String bookingId,
    required String customerPhone,
  }) async {
    final response = await client.functions.invoke(
      'cancel-map-booking',
      body: {
        'booking_id': bookingId,
        'customer_phone': customerPhone,
      },
    );

    if (response.status >= 400) {
      throw Exception('Function error: ${response.status}');
    }

    return Map<String, dynamic>.from(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> cancelAllMapBookings({
    required String customerPhone,
    String language = 'ar',
  }) async {
    final response = await client.functions.invoke(
      'cancel-all-map-bookings',
      body: {
        'customer_phone': customerPhone,
        'language': language,
      },
    );

    if (response.status >= 400) {
      throw Exception('Function error: ${response.status}');
    }

    return Map<String, dynamic>.from(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> whatsappSend({
    required String phone,
    required String message,
    String? conversationId,
  }) async {
    final response = await client.functions.invoke(
      'whatsapp-send',
      body: {
        'phone': phone,
        'message': message,
        if (conversationId != null) 'conversation_id': conversationId,
      },
    );

    if (response.status >= 400) {
      throw Exception('Function error: ${response.status}');
    }

    return Map<String, dynamic>.from(response.data as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> fetchCustomerBookings(String customerPhone) async {
    final data = await client
        .from('bookings')
        .select('*,services(name,price),stations(name)')
        .eq('customer_phone', customerPhone)
        .order('created_at', ascending: false);

    return (data as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> updateBookingStatus({
    required String bookingId,
    required String status,
  }) async {
    final data = await client
        .from('bookings')
        .update({'status': status})
        .eq('id', bookingId)
        .select();

    return (data as List<dynamic>).cast<Map<String, dynamic>>();
  }
}
