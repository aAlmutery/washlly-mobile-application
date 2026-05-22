import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/service_model.dart';
import '../models/station.dart';
import '../services/supabase_service.dart';
import '../widgets/bottom_nav_scaffold.dart';

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
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay(hour: 12, minute: 0);
  List<ServiceModel> _services = [];
  ServiceModel? _selectedService;
  bool _loading = false;
  String? _resultMessage;

  @override
  void initState() {
    super.initState();
    if (widget.station != null) {
      _loadServices();
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
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final lat = double.tryParse(_latitudeController.text.trim());
    final lng = double.tryParse(_longitudeController.text.trim());
    if (lat == null || lng == null) {
      setState(() {
        final loc = AppLocalizations.of(context)!;
        _resultMessage = loc.invalidCoordinates;
      });
      return;
    }
    setState(() {
      _loading = true;
      _resultMessage = null;
    });
    try {
      final booking = await SupabaseService.instance.createQuickBooking(
        customerName: _nameController.text.trim(),
        customerPhone: _phoneController.text.trim(),
        bookingDate: _formattedDate,
        bookingTime: _formattedTimeIso,
        serviceKind: 'quick',
        customerLat: lat,
        customerLng: lng,
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
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
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
                TextFormField(
                  controller: _latitudeController,
                  decoration: InputDecoration(labelText: loc.latitudeLabel),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) => value?.trim().isEmpty == true ? loc.locationRequired : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _longitudeController,
                  decoration: InputDecoration(labelText: loc.longitudeLabel),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) => value?.trim().isEmpty == true ? loc.locationRequired : null,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loading ? null : _createQuickBooking,
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
