import 'package:flutter/material.dart';
import 'dart:async';
import '../models/station.dart';
import '../services/supabase_service.dart';
import '../widgets/bottom_nav_scaffold.dart';
import '../widgets/station_card.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'customer/booking_screen.dart';

class StationListScreen extends StatefulWidget {
  static const routeName = '/stations';

  const StationListScreen({super.key});

  @override
  State<StationListScreen> createState() => _StationListScreenState();
}

class _StationListScreenState extends State<StationListScreen> {
  late final Future<void> _loadFuture;
  late final ScrollController _scrollController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  List<Station> _stations = [];
  List<Station> _filteredStations = [];
  List<String> _serviceNames = [];
  String? _selectedService;
  bool _filterLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreStations = true;
  int _currentPage = 0;
  final int _pageSize = 10;
  final TextEditingController _serviceSearchController = TextEditingController();
  Timer? _filterDebounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadFuture = _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _areaController.dispose();
    _serviceSearchController.dispose();
    _scrollController.dispose();
    _filterDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final stations = await SupabaseService.instance.fetchStationsPaginated(
      limit: _pageSize,
      offset: 0,
    );
    final serviceNames = await SupabaseService.instance.fetchServiceNames();
    setState(() {
      _stations = stations;
      _filteredStations = stations;
      _serviceNames = serviceNames;
      _currentPage = 0;
      _hasMoreStations = stations.length == _pageSize;
    });
  }

  void _onScroll() {
    // Only load more if no filters are active
    final hasSearch = _searchController.text.trim().isNotEmpty;
    final hasArea = _areaController.text.trim().isNotEmpty;
    final hasService = _selectedService != null && _selectedService!.isNotEmpty;

    if (!hasSearch && !hasArea && !hasService) {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 500) {
        if (!_isLoadingMore && _hasMoreStations) {
          _loadMoreStations();
        }
      }
    }
  }

  Future<void> _loadMoreStations() async {
    if (_isLoadingMore || !_hasMoreStations) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final newStations = await SupabaseService.instance.fetchStationsPaginated(
        limit: _pageSize,
        offset: nextPage * _pageSize,
      );

      if (newStations.length < _pageSize) {
        _hasMoreStations = false;
      }

      setState(() {
        _stations.addAll(newStations);
        // Only update filtered list - don't duplicate
        _filteredStations = _stations;
        _currentPage = nextPage;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _openServicePicker() async {
    _serviceSearchController.clear();
    final selected = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        var searchQuery = '';

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final loc = AppLocalizations.of(context)!;
            final options = _serviceNames
                .where((service) => service.toLowerCase().contains(searchQuery.toLowerCase()))
                .toList();

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _serviceSearchController,
                    decoration: InputDecoration(
                      labelText: loc.searchServiceLabel,
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onChanged: (value) {
                      setSheetState(() {
                        searchQuery = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: Text(loc.allServices),
                    leading: Radio<String?>(
                      value: null,
                      groupValue: _selectedService,
                      onChanged: (value) {
                        Navigator.pop(context, value);
                      },
                    ),
                    onTap: () => Navigator.pop(context, null),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: options.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(loc.noMatchingServices),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final service = options[index];
                              return ListTile(
                                title: Text(service),
                                leading: Radio<String?>(
                                  value: service,
                                  groupValue: _selectedService,
                                  onChanged: (value) {
                                    Navigator.pop(context, value);
                                  },
                                ),
                                onTap: () => Navigator.pop(context, service),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (selected != null || _selectedService != selected) {
      setState(() {
        _selectedService = selected;
      });
      _applyFilters();
    }
  }

  void _onFilterTextChanged() {
    // Cancel previous timer
    _filterDebounceTimer?.cancel();
    
    // Start new timer - apply filters after 500ms of no typing
    _filterDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _applyFilters();
    });
  }

  Future<void> _applyFilters() async {
    setState(() {
      _filterLoading = true;
    });

    final search = _searchController.text.trim().toLowerCase();
    final area = _areaController.text.trim().toLowerCase();
    Set<String>? serviceStationIds;

    if (_selectedService != null && _selectedService!.isNotEmpty) {
      final ids = await SupabaseService.instance.fetchStationIdsByServiceName(_selectedService!);
      serviceStationIds = ids.toSet();
    }

    // If any filter (search, area, or service) is active, search the entire database
    if (search.isNotEmpty || area.isNotEmpty || (_selectedService != null && _selectedService!.isNotEmpty)) {
      final searchResults = await SupabaseService.instance.searchStations(
        query: search,
        areaFilter: area.isNotEmpty ? area : null,
        serviceStationIds: serviceStationIds,
      );

      setState(() {
        _filteredStations = searchResults;
        _filterLoading = false;
      });
    } else {
      // No filters active, use pagination with loaded stations
      setState(() {
        _filteredStations = _stations;
        _filterLoading = false;
      });
      
      // Scroll back to top
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _resetFilters() {
    _searchController.clear();
    _areaController.clear();
    setState(() {
      _selectedService = null;
      _filteredStations = _stations;
    });
    
    // Scroll back to top
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return BottomNavScaffold(
      currentIndex: 1,
      title: loc.stationListTitle,
      body: FutureBuilder<void>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingSkeleton();
          }
          if (snapshot.hasError) {
            return Center(child: Text('${loc.errorPrefix}${snapshot.error}'));
          }
          if (_stations.isEmpty) {
            return Center(child: Text(loc.noStationsAvailable));
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              labelText: loc.searchStationLabel,
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: (_) => _onFilterTextChanged(),
                          ),
                        ),
                        if (_searchController.text.isNotEmpty ||
                            _areaController.text.isNotEmpty ||
                            (_selectedService != null && _selectedService!.isNotEmpty))
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: _resetFilters,
                              tooltip: 'Clear Filters',
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _areaController,
                            decoration: InputDecoration(
                              labelText: loc.areaLabel,
                              prefixIcon: const Icon(Icons.location_on),
                            ),
                            onChanged: (_) => _onFilterTextChanged(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: _openServicePicker,
                            child: AbsorbPointer(
                              child: TextFormField(
                                  decoration: InputDecoration(
                                    labelText: loc.serviceLabel,
                                    prefixIcon: const Icon(Icons.room_service),
                                    hintText: loc.chooseServiceHint,
                                    suffixIcon: Icon(
                                      _selectedService == null ? Icons.arrow_drop_down : Icons.clear,
                                    ),
                                  ),
                                  controller: TextEditingController(
                                    text: _selectedService ?? loc.allServices,
                                  ),
                                  readOnly: true,
                                ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_filterLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                ),
              Expanded(
                child: _filteredStations.isEmpty
                    ? Center(child: Text(loc.noStationsMatchFilters))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredStations.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _filteredStations.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final station = _filteredStations[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: StationCard(
                              station: station,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BookingScreen(station: station),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: 150,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
