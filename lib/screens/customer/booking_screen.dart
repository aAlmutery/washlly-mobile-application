import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../models/service_model.dart';
import '../../models/station.dart';
import '../../services/session_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/bottom_nav_scaffold.dart';

class BookingScreen extends StatefulWidget {
  static const routeName = '/booking';

  final Station? station;
  const BookingScreen({super.key, this.station});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay(hour: 12, minute: 0);
  List<ServiceModel> _services = [];
  ServiceModel? _selectedService;
  bool _loading = false;
  String? _resultMessage;

  Position? _position;
  bool _loadingLocation = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    if (widget.station != null) {
      _loadServices();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        _fetchLocation();
        final session = await SessionService.instance.loadCustomerSession();
        if (mounted && session != null) {
          _nameController.text = session.customerName;
          _phoneController.text = session.customerPhone;
        }
      });
    }
  }

  Future<void> _fetchLocation() async {
    setState(() { _loadingLocation = true; _locationError = null; });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locationError = 'خدمة الموقع معطّلة. يرجى تفعيلها من إعدادات الجهاز.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        setState(() => _locationError = 'تم رفض إذن الموقع. يرجى منح الإذن للمتابعة.');
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => _locationError = 'تم رفض إذن الموقع بشكل دائم. يرجى تفعيله من إعدادات التطبيق.');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) setState(() => _position = position);
    } catch (_) {
      if (mounted) setState(() => _locationError = 'تعذّر تحديد الموقع. يرجى المحاولة مجدداً.');
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<void> _loadServices() async {
    try {
      final services = await SupabaseService.instance.fetchServices(widget.station!.id);
      if (mounted) {
        setState(() {
          _services = services;
          _selectedService = services.isNotEmpty ? services.first : null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          final loc = AppLocalizations.of(context)!;
          _resultMessage = '${loc.bookingLoadServicesFailed}$error';
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  String get _formattedDate => DateFormat('yyyy-MM-dd').format(_selectedDate);
  String get _formattedTime => _selectedTime.format(context);
  String get _formattedTimeIso => '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

  Future<void> _createMapBooking() async {
    if (!_formKey.currentState!.validate() || widget.station == null || _selectedService == null) {
      return;
    }
    setState(() {
      _loading = true;
      _resultMessage = null;
    });
    try {
      final discount = await SupabaseService.instance.spinBookingDiscount(
        stationId: widget.station!.id,
        serviceId: _selectedService!.id,
        bookingDate: _formattedDate,
        bookingTime: _formattedTimeIso,
        customerPhone: _phoneController.text.trim(),
      );
      final spinToken = discount['token'] as String?;
      final spinPercent = discount['discountPercent'] as int? ?? 0;
      final booking = await SupabaseService.instance.createMapBooking(
        stationId: widget.station!.id,
        serviceId: _selectedService!.id,
        customerName: _nameController.text.trim(),
        customerPhone: _phoneController.text.trim(),
        bookingDate: _formattedDate,
        bookingTime: _formattedTimeIso,
        spinDiscountPercent: spinPercent,
        spinToken: spinToken!,
      );
      setState(() {
        final loc = AppLocalizations.of(context)!;
        _resultMessage = '${loc.bookingCreated} #${booking['bookingNumber']}';
      });
    } catch (error) {
      setState(() {
        final loc = AppLocalizations.of(context)!;
        _resultMessage = '${loc.bookingErrorPrefix}$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _createQuickBooking() async {
    if (!_formKey.currentState!.validate() || _position == null) return;
    setState(() { _loading = true; _resultMessage = null; });
    try {
      final booking = await SupabaseService.instance.createQuickBooking(
        customerName: _nameController.text.trim(),
        customerPhone: _phoneController.text.trim(),
        bookingDate: _formattedDate,
        bookingTime: _formattedTimeIso,
        serviceKind: 'quick',
        customerLat: _position!.latitude,
        customerLng: _position!.longitude,
      );
      setState(() {
        final loc = AppLocalizations.of(context)!;
        _resultMessage = '${loc.quickBookingSentPrefix}${booking['target_count']}${loc.quickBookingSentSuffix}';
      });
    } catch (error) {
      setState(() {
        final loc = AppLocalizations.of(context)!;
        _resultMessage = '${loc.quickBookingFailedPrefix}$error';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildLocationCard() {
    if (_loadingLocation) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: const [
              SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 16),
              Text('جاري تحديد موقعك...'),
            ],
          ),
        ),
      );
    }
    if (_locationError != null) {
      return Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_off, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_locationError!, style: const TextStyle(color: Colors.red))),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _fetchLocation,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Geolocator.openAppSettings(),
                      icon: const Icon(Icons.settings, size: 18),
                      label: const Text('الإعدادات'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    if (_position != null) {
      return Card(
        color: Colors.green.shade50,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: const [
              Icon(Icons.location_on, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Text(
                'تم تحديد موقعك بنجاح',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return BottomNavScaffold(
      currentIndex: 3,
      title: widget.station != null ? '${loc.bookingTitleAtPrefix}${widget.station!.name}' : loc.quickBookingTitle,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (widget.station != null) ...[
                Text('${loc.stationLabelPrefix}${widget.station!.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                Text(widget.station!.address),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: loc.fullNameLabel),
                validator: (value) => value?.trim().isEmpty == true ? loc.fullNameRequired : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(labelText: loc.phoneLabel),
                keyboardType: TextInputType.phone,
                validator: (value) => value?.trim().isEmpty == true ? loc.phoneRequired : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickDate,
                      child: Text('${loc.dateLabelPrefix}$_formattedDate'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickTime,
                      child: Text('${loc.timeLabelPrefix}$_formattedTime'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (widget.station != null) ...[
                if (_services.isEmpty)
                  const Center(child: CircularProgressIndicator())
                else
                  DropdownButtonFormField<ServiceModel>(
                    value: _selectedService,
                    decoration: InputDecoration(labelText: loc.chooseServiceLabel),
                    items: _services
                        .map(
                          (service) => DropdownMenuItem(
                            value: service,
                            child: Text('${service.name} - ${service.price}${loc.servicePriceCurrencySuffix}'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedService = value;
                      });
                    },
                  ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loading ? null : _createMapBooking,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(_loading ? loc.bookingButtonBooking : loc.bookingButtonMap),
                  ),
                ),
              ],
              if (widget.station == null) ...[
                _buildLocationCard(),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: (_loading || _loadingLocation || _position == null) ? null : _createQuickBooking,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(_loading ? loc.quickSendingText : loc.quickBookingButton),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (_resultMessage != null)
                Text(
                  _resultMessage!,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
