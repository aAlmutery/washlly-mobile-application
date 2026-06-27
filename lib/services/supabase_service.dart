import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/service_model.dart';
import '../models/station.dart';

class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();
  final SupabaseClient client = Supabase.instance.client;

  /// Extracts the human-readable message from an error response body and throws.
  /// Accepts a Map (JSON body), a plain String, or null.
  Never _throwFunctionError(dynamic data) {
    String? msg;
    if (data is Map) {
      msg = (data['message'] ?? data['error']) as String?;
    } else if (data is String && data.isNotEmpty) {
      msg = data;
    }
    throw Exception(msg ?? 'Something went wrong. Please try again.');
  }

  /// Invokes a Supabase edge function and returns the raw response data.
  /// On HTTP error or FunctionException, throws with only the API message.
  Future<dynamic> _invoke(
    String function, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await client.functions.invoke(
        function,
        body: body,
        headers: headers,
      );
      if (response.status >= 400) _throwFunctionError(response.data);
      return response.data;
    } on FunctionException catch (e) {
      _throwFunctionError(e.details);
    }
  }

  Future<List<Station>> fetchStations() async {
    final data = await client
        .from('stations')
        .select('id,name,address,detailed_address,latitude,longitude,is_active,rating_average,rating_count')
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

  Future<void> addService({
    required String stationId,
    required String name,
    required int price,
    int? durationMinutes,
    double? customerDiscount,
    int sortOrder = 0,
  }) async {
    await client.from('services').insert({
      'station_id': stationId,
      'name': name,
      'price': price,
      'duration_minutes': durationMinutes,
      'customer_discount': customerDiscount,
      'sort_order': sortOrder,
      'is_active': true,
    });
  }

  Future<List<ServiceModel>> fetchServices(String stationId) async {
    final data = await client
        .from('services')
        .select('id,name,price,duration_minutes,customer_discount,sort_order')
        .eq('station_id', stationId)
        .eq('is_active', true)
        .order('sort_order');

    return (data as List<dynamic>)
        .map((item) => ServiceModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Returns distinct active service names with the lowest price found
  /// across all stations. Used by the home screen service grid.
  Future<List<({String name, int minPrice})>> fetchDistinctServicesWithPrice() async {
    final data = await client
        .from('services')
        .select('name,price')
        .eq('is_active', true)
        .order('name');

    final Map<String, int> nameToMin = {};
    for (final item in (data as List)) {
      final name = (item as Map)['name'] as String;
      final price = ((item)['price'] as num).toInt();
      if (!nameToMin.containsKey(name) || price < nameToMin[name]!) {
        nameToMin[name] = price;
      }
    }

    return (nameToMin.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key)))
        .map((e) => (name: e.key, minPrice: e.value))
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
    final data = await _invoke('owner-self-register', body: {
      'owner_name': ownerName,
      'owner_phone': ownerPhone,
      'email': email,
      'password': password,
      'free_requests_quota': freeRequestsQuota,
      'station': station,
      'services': services,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  /// Fetches quota, active status, outstanding debt, and latest active
  /// subscription for the owner's station. Returns a Map with keys:
  /// free_requests_quota, is_active, outstanding_debt, subscription (nullable Map).
  Future<Map<String, dynamic>> fetchOwnerInfo(String stationId) async {
    final ownerRow = await client
        .from('station_owners')
        .select('free_requests_quota,outstanding_debt')
        .eq('station_id', stationId)
        .single();

    // Suspension status lives on stations (is_active, suspension_reason, suspended_at)
    final stationRow = await client
        .from('stations')
        .select('is_active,suspension_reason,suspended_at')
        .eq('id', stationId)
        .single();

    Map<String, dynamic>? subscription;
    try {
      subscription = await client
          .from('subscriptions')
          .select('package_code,request_limit,requests_used,status,start_date,end_date,paid_at')
          .eq('station_id', stationId)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
    } catch (_) {}

    return {
      ...Map<String, dynamic>.from(ownerRow as Map),
      ...Map<String, dynamic>.from(stationRow as Map),
      'subscription': subscription,
    };
  }

  Future<Map<String, dynamic>> ownerLoginLookup(String identifier) async {
    final data = await _invoke('owner-login-lookup', body: {'identifier': identifier});
    return Map<String, dynamic>.from(data as Map);
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
    final data = await _invoke('spin-booking-discount', body: {
      'station_id': stationId,
      'service_id': serviceId,
      'booking_date': bookingDate,
      'booking_time': bookingTime,
      'customer_phone': customerPhone,
    });
    return Map<String, dynamic>.from(data as Map);
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
    final data = await _invoke('create-map-booking', body: {
      'station_id': stationId,
      'service_id': serviceId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'booking_date': bookingDate,
      'booking_time': bookingTime,
      'spin_discount_percent': spinDiscountPercent,
      'spin_token': spinToken,
      'language': language,
    });
    return Map<String, dynamic>.from(data as Map);
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
    final data = await _invoke('create-quick-booking', body: {
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'booking_date': bookingDate,
      'booking_time': bookingTime,
      'service_kind': serviceKind,
      'language': language,
      'customer_lat': customerLat,
      'customer_lng': customerLng,
      'exclude_station_ids': excludeStationIds,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> cancelMapBooking({
    required String bookingId,
    required String customerPhone,
  }) async {
    final data = await _invoke('cancel-map-booking', body: {
      'booking_id': bookingId,
      'customer_phone': customerPhone,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> cancelAllMapBookings({
    required String customerPhone,
    String language = 'ar',
  }) async {
    final data = await _invoke('cancel-all-map-bookings', body: {
      'customer_phone': customerPhone,
      'language': language,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> whatsappSend({
    required String phone,
    required String message,
    String? conversationId,
  }) async {
    final data = await _invoke('whatsapp-send', body: {
      'phone': phone,
      'message': message,
      if (conversationId != null) 'conversation_id': conversationId,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> fetchCustomerBookings(
    String customerPhone, {
    String? sessionToken,
  }) async {
    // Always use direct REST so services(name,price) and spin_discount_percent
    // are included. The customer-list-bookings edge function returns services
    // with name only (no price), so we skip it here.
    final data = await client
        .from('bookings')
        .select('*,services(name,price),stations(name)')
        .eq('customer_phone', customerPhone)
        .order('created_at', ascending: false);
    return (data as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
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
    final data = await _invoke('customer-login-by-phone', body: body);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<int> fetchUnreadNotificationCount({
    required String customerPhone,
    required String sessionToken,
  }) async {
    final data = await _invoke('customer-get-inbox', body: {
      'customer_phone': customerPhone,
      'session_token': sessionToken,
    });
    final notifications = (data as Map)['notifications'] as List? ?? [];
    return notifications.where((n) => (n as Map)['is_read'] == false).length;
  }

  Future<Map<String, dynamic>> customerGetInbox({
    required String customerPhone,
    required String sessionToken,
  }) async {
    final data = await _invoke('customer-get-inbox', body: {
      'customer_phone': customerPhone,
      'session_token': sessionToken,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> customerManageBooking({
    required String bookingId,
    required String action,
    required String customerPhone,
    required String sessionToken,
    String? bookingDate,
    String? bookingTime,
  }) async {
    final data = await _invoke('customer-manage-booking', body: {
      'booking_id': bookingId,
      'action': action,
      'customer_phone': customerPhone,
      'session_token': sessionToken,
      if (bookingDate != null) 'booking_date': bookingDate,
      if (bookingTime != null) 'booking_time': bookingTime,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> customerSubmitRating({
    required String bookingId,
    required String customerPhone,
    required String sessionToken,
    required int rating,
  }) async {
    final data = await _invoke('customer-submit-rating', body: {
      'booking_id': bookingId,
      'customer_phone': customerPhone,
      'session_token': sessionToken,
      'rating': rating,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> customerMarkNotificationRead({
    required String customerPhone,
    required String sessionToken,
    String? notificationId,
    bool markAll = false,
  }) async {
    final data = await _invoke('customer-mark-notification-read', body: {
      'customer_phone': customerPhone,
      'session_token': sessionToken,
      if (notificationId != null) 'notification_id': notificationId,
      if (markAll) 'mark_all': true,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  // Owner API Methods
  Future<Map<String, dynamic>> ownerLoginByPhone({
    required String ownerPhone,
  }) async {
    final data = await _invoke('owner-login-by-phone', body: {'owner_phone': ownerPhone});
    return Map<String, dynamic>.from(data as Map);
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
    return (data as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList();
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
    final data = await _invoke(
      'owner-manage-booking',
      body: {
        'booking_id': bookingId,
        'action': action,
        if (proposedDate != null) 'booking_date': proposedDate,
        if (proposedTime != null) 'booking_time': proposedTime,
      },
      headers: {'Authorization': 'Bearer $sessionToken'},
    );
    if (data == null) return {};
    return Map<String, dynamic>.from(data as Map);
  }

  /// Postpone a confirmed booking to pending_customer_approval via direct REST
  /// (owner-manage-booking only accepts pending/pending_owner_approval).
  Future<void> ownerPostponeConfirmedBooking({
    required String bookingId,
    required String stationId,
    required String proposedDate,
    required String proposedTime,
  }) async {
    final rows = await client
        .from('bookings')
        .update({
          'status': 'pending_customer_approval',
          'proposed_date': proposedDate,
          'proposed_time': proposedTime,
        })
        .eq('id', bookingId)
        .eq('station_id', stationId)
        .select('id');
    if ((rows as List).isEmpty) {
      throw Exception('لم يتم تحديث الحجز — تحقق من الصلاحيات');
    }
  }

  /// Update booking status directly (used by owner for confirmed → completed/cancelled).
  /// Throws if no rows were updated (e.g. RLS policy blocked the write).
  Future<void> ownerUpdateBookingStatus({
    required String bookingId,
    required String stationId,
    required String newStatus,
  }) async {
    final rows = await client
        .from('bookings')
        .update({'status': newStatus})
        .eq('id', bookingId)
        .eq('station_id', stationId)
        .select('id');
    if ((rows as List).isEmpty) {
      throw Exception('لم يتم تحديث الحجز — تحقق من الصلاحيات');
    }
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
    final data = await _invoke('resolve-booking-conflict', body: {
      'booking_id': bookingId,
      'resolution_action': resolutionAction,
      'reason': reason,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> saveDeviceToken({
    required String phone,
    required String role,
    required String token,
    required String platform,
    required String language,
  }) async {
    await _invoke('register-device-token', body: {
      'action': 'save',
      'phone': phone,
      'role': role,
      'token': token,
      'platform': platform,
      'language': language,
    });
  }

  Future<void> deleteDeviceToken(String token) async {
    await _invoke('register-device-token', body: {
      'action': 'delete',
      'token': token,
    });
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
