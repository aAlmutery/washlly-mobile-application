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

  Future<List<Station>> fetchStationsPaginated({
    required int limit,
    required int offset,
  }) async {
    final data = await client
        .from('stations')
        .select('id,name,address,detailed_address,latitude,longitude,is_active')
        .eq('is_active', true)
        .order('name')
        .range(offset, offset + limit - 1);

    return (data as List<dynamic>)
        .map((item) => Station.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Station>> searchStations({
    required String query,
    required String? areaFilter,
    required Set<String>? serviceStationIds,
  }) async {
    var request = client
        .from('stations')
        .select('id,name,address,detailed_address,latitude,longitude,is_active')
        .eq('is_active', true);

    if (query.isNotEmpty) {
      request = request.ilike('name', '%$query%');
    }

    if (areaFilter != null && areaFilter.isNotEmpty) {
      request = request.or('address.ilike.%$areaFilter%,detailed_address.ilike.%$areaFilter%');
    }

    final data = await request.order('name');

    final stations = (data as List<dynamic>)
        .map((item) => Station.fromJson(item as Map<String, dynamic>))
        .toList();

    if (serviceStationIds != null && serviceStationIds.isNotEmpty) {
      return stations.where((station) => serviceStationIds.contains(station.id)).toList();
    }

    return stations;
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

  Future<Map<String, dynamic>> ownerSignIn({
    required String phone,
    required String password,
  }) async {
    final lookup = await ownerLoginLookup(phone);
    final email = lookup['email'] as String;
    final authResponse = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final userId = authResponse.user?.id ?? '';
    final accessToken = authResponse.session?.accessToken ?? '';

    final row = await client
        .from('station_owners')
        .select('owner_phone, station_id, stations(name)')
        .eq('user_id', userId)
        .single();

    return {
      'station_id': row['station_id'] as String? ?? '',
      'owner_phone': row['owner_phone'] as String? ?? '',
      'session_token': accessToken,
      'station_name':
          (row['stations'] as Map<String, dynamic>?)?['name'] as String? ?? '',
    };
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

  // Customer API Methods
  Future<Map<String, dynamic>> customerLoginByPhone({
    required String customerPhone,
    String? customerName,
  }) async {
    final body = <String, dynamic>{'customer_phone': customerPhone};
    if (customerName != null && customerName.isNotEmpty) {
      body['customer_name'] = customerName;
    }
    final response = await client.functions.invoke(
      'customer-login-by-phone',
      body: body,
    );

    if (response.status >= 400) {
      throw Exception('Function error: ${response.status}');
    }

    return Map<String, dynamic>.from(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> customerGetInbox({
    required String customerPhone,
    required String sessionToken,
  }) async {
    final response = await client.functions.invoke(
      'customer-get-inbox',
      body: {
        'customer_phone': customerPhone,
        'session_token': sessionToken,
      },
    );

    if (response.status >= 400) {
      throw Exception('Function error: ${response.status}');
    }

    return Map<String, dynamic>.from(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> customerManageBooking({
    required String bookingId,
    required String action,
    required String customerPhone,
    required String sessionToken,
    String? bookingDate,
    String? bookingTime,
  }) async {
    final body = {
      'booking_id': bookingId,
      'action': action,
      'customer_phone': customerPhone,
      'session_token': sessionToken,
      if (bookingDate != null) 'booking_date': bookingDate,
      if (bookingTime != null) 'booking_time': bookingTime,
    };

    final response = await client.functions.invoke(
      'customer-manage-booking',
      body: body,
    );

    if (response.status >= 400) {
      throw Exception('Function error: ${response.status}');
    }

    return Map<String, dynamic>.from(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> customerSubmitRating({
    required String bookingId,
    required String customerPhone,
    required String sessionToken,
    required int rating,
  }) async {
    final response = await client.functions.invoke(
      'customer-submit-rating',
      body: {
        'booking_id': bookingId,
        'customer_phone': customerPhone,
        'session_token': sessionToken,
        'rating': rating,
      },
    );

    if (response.status >= 400) {
      throw Exception('Function error: ${response.status}');
    }

    return Map<String, dynamic>.from(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> customerMarkNotificationRead({
    required String customerPhone,
    required String sessionToken,
    String? notificationId,
    bool markAll = false,
  }) async {
    final body = {
      'customer_phone': customerPhone,
      'session_token': sessionToken,
      if (notificationId != null) 'notification_id': notificationId,
      if (markAll) 'mark_all': true,
    };

    final response = await client.functions.invoke(
      'customer-mark-notification-read',
      body: body,
    );

    if (response.status >= 400) {
      throw Exception('Function error: ${response.status}');
    }

    return Map<String, dynamic>.from(response.data as Map<String, dynamic>);
  }

  // Owner API Methods
  Future<Map<String, dynamic>> ownerLoginByPhone({
    required String ownerPhone,
  }) async {
    final response = await client.functions.invoke(
      'owner-login-by-phone',
      body: {
        'owner_phone': ownerPhone,
      },
    );

    if (response.status >= 400) {
      throw Exception('Function error: ${response.status}');
    }

    return Map<String, dynamic>.from(response.data as Map<String, dynamic>);
  }

  /// Fetch bookings for a station via direct REST (documented in API docs).
  Future<List<Map<String, dynamic>>> ownerGetBookings({
    required String stationId,
    required String ownerPhone,
    required String sessionToken,
  }) async {
    final data = await client
        .from('bookings')
        .select('*,services(name,price),stations(name)')
        .eq('station_id', stationId)
        .order('created_at', ascending: false);
    return (data as List<dynamic>).cast<Map<String, dynamic>>();
  }

  /// Confirm, reject, or propose a new time for a booking via owner-manage-booking.
  /// [action] must be 'confirm', 'reject', or 'postpone'.
  Future<Map<String, dynamic>> ownerManageBooking({
    required String bookingId,
    required String action,
    required String sessionToken,
    String? proposedDate,
    String? proposedTime,
  }) async {
    final body = <String, dynamic>{
      'booking_id': bookingId,
      'action': action,
      if (proposedDate != null) 'booking_date': proposedDate,
      if (proposedTime != null) 'booking_time': proposedTime,
    };

    try {
      final response = await client.functions.invoke(
        'owner-manage-booking',
        body: body,
        headers: {'Authorization': 'Bearer $sessionToken'},
      );
      return Map<String, dynamic>.from(response.data as Map<dynamic, dynamic>);
    } on FunctionException catch (e) {
      final details = e.details;
      String? msg;
      if (details is Map) {
        msg = details['error'] as String? ?? details['message'] as String?;
      }
      throw Exception(msg ?? 'حدث خطأ غير متوقع (${e.status})');
    }
  }

  /// Postpone a confirmed booking to pending_customer_approval via direct REST
  /// (owner-manage-booking only accepts pending/pending_owner_approval).
  Future<void> ownerPostponeConfirmedBooking({
    required String bookingId,
    required String stationId,
    required String proposedDate,
    required String proposedTime,
  }) async {
    await client
        .from('bookings')
        .update({
          'status': 'pending_customer_approval',
          'proposed_date': proposedDate,
          'proposed_time': proposedTime,
        })
        .eq('id', bookingId)
        .eq('station_id', stationId);
  }

  /// Update booking status directly (used by owner for confirmed → completed/cancelled).
  Future<void> ownerUpdateBookingStatus({
    required String bookingId,
    required String stationId,
    required String newStatus,
  }) async {
    await client
        .from('bookings')
        .update({'status': newStatus})
        .eq('id', bookingId)
        .eq('station_id', stationId);
  }

  // Timeout and Alert Management
  Future<List<Map<String, dynamic>>> getBookingAlerts({
    required String bookingId,
  }) async {
    final data = await client
        .from('booking_alerts')
        .select('*')
        .eq('booking_id', bookingId)
        .order('created_at', ascending: false);

    return (data as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getTimeoutAlerts({
    required String customerPhone,
  }) async {
    final data = await client
        .from('timeout_alerts')
        .select('*')
        .eq('customer_phone', customerPhone)
        .eq('status', 'active')
        .order('timeout_time', ascending: true);

    return (data as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> acknowledgeTimeoutAlert({
    required String alertId,
  }) async {
    final data = await client
        .from('timeout_alerts')
        .update({'status': 'acknowledged'})
        .eq('id', alertId)
        .select()
        .single();

    return (data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> resolveBookingConflict({
    required String bookingId,
    required String resolutionAction,
    required String reason,
  }) async {
    final response = await client.functions.invoke(
      'resolve-booking-conflict',
      body: {
        'booking_id': bookingId,
        'resolution_action': resolutionAction,
        'reason': reason,
      },
    );

    if (response.status >= 400) {
      throw Exception('Function error: ${response.status}');
    }

    return Map<String, dynamic>.from(response.data as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> getConflictingBookings({
    required String stationId,
    required DateTime timeSlot,
  }) async {
    final dateStr = timeSlot.toString().split(' ')[0];
    final data = await client
        .from('bookings')
        .select('*')
        .eq('station_id', stationId)
        .eq('booking_date', dateStr)
        .or('status.eq.pending,status.eq.confirmed');

    return (data as List<dynamic>).cast<Map<String, dynamic>>();
  }
}
