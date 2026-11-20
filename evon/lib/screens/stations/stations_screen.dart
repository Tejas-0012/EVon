import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/station_model.dart';
import '../../core/services/station_service.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_theme.dart';
import 'station_detail_screen.dart';

class StationsScreen extends StatefulWidget {
  const StationsScreen({super.key});

  @override
  State<StationsScreen> createState() => _StationsScreenState();
}

class _StationsScreenState extends State<StationsScreen> {
  final StationService _stationService = StationService();
  final LocationService _locationService = LocationService();
  final MapController _mapController = MapController();

  List<StationModel> _stations = [];
  List<StationModel> _filtered = [];
  bool _isLoading = true;
  bool _isMapView = false;
  bool _isFetchingLocation = false;

  final TextEditingController _searchCtrl = TextEditingController();

  LatLng? _currentLocation;
  String? _currentLocationName;
  final LatLng _center = const LatLng(12.9716, 77.5946);

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStations() async {
    setState(() => _isLoading = true);
    final list = await _stationService.getAllStations();
    if (!mounted) return;
    setState(() {
      _stations = list;
      _filtered = list;
      _isLoading = false;
      _currentLocation = null;
      _currentLocationName = null;
      _searchCtrl.clear();
    });
  }

  void _filterStations(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = _stations;
      } else {
        _filtered = _stations.where((s) {
          return s.stationName.toLowerCase().contains(query.toLowerCase()) ||
              s.address.toLowerCase().contains(query.toLowerCase()) ||
              s.city.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  /// 📍 Fetches live device GPS coordinates and reverse-geocodes with Google Maps API
  Future<void> _fetchCurrentLocation() async {
    setState(() => _isFetchingLocation = true);

    try {
      final pos = await _locationService.getCurrentPosition();
      final double lat = pos?.latitude ?? 12.9716;
      final double lng = pos?.longitude ?? 77.5946;

      // Reverse geocode via Google Maps Geocoding API
      final geo = await _locationService.reverseGeocode(lat, lng);
      final userCoords = LatLng(lat, lng);

      // Fetch nearby stations sorted by distance from current location
      final nearby = await _stationService.getNearbyStations(
        lat: lat,
        lng: lng,
        maxDistanceKm: 30.0,
      );

      if (!mounted) return;

      setState(() {
        _currentLocation = userCoords;
        _currentLocationName = geo?.formattedAddress ?? '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
        _isFetchingLocation = false;
        if (nearby.isNotEmpty) {
          _stations = nearby;
          _filtered = nearby;
        }
      });

      if (_isMapView) {
        try {
          _mapController.move(userCoords, 13.5);
        } catch (_) {}
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.my_location_rounded, color: AppTheme.neonGreen, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '📍 Current Location: ${geo?.area.isNotEmpty == true ? geo!.area : _currentLocationName!}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.bgCard,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  /// 🔍 Geocode location search text with Google Maps API and center stations around it
  Future<void> _searchLocationWithGoogle(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isLoading = true);

    final geo = await _locationService.geocodeAddress(query);
    if (geo != null) {
      final target = LatLng(geo.latitude, geo.longitude);
      final nearby = await _stationService.getNearbyStations(
        lat: geo.latitude,
        lng: geo.longitude,
        maxDistanceKm: 30.0,
      );

      if (!mounted) return;

      setState(() {
        _currentLocation = target;
        _currentLocationName = geo.formattedAddress;
        _isLoading = false;
        if (nearby.isNotEmpty) {
          _stations = nearby;
          _filtered = nearby;
        }
      });

      if (_isMapView) {
        try {
          _mapController.move(target, 13.0);
        } catch (_) {}
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔍 Google Maps: ${geo.formattedAddress}'),
          backgroundColor: AppTheme.bgCard,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('Charging Network', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_isMapView ? Icons.view_list_rounded : Icons.map_rounded, color: AppTheme.neonCyan),
            tooltip: _isMapView ? 'List View' : 'Map View',
            onPressed: () => setState(() => _isMapView = !_isMapView),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.neonGreen),
            tooltip: 'Reset & Reload Stations',
            onPressed: _loadStations,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Bar with Google Geocoding & GPS My Location button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _filterStations,
                    onSubmitted: _searchLocationWithGoogle,
                    style: const TextStyle(color: AppTheme.textMain),
                    decoration: InputDecoration(
                      hintText: 'Search station or location (e.g. Hebbal)...',
                      prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.neonGreen),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_searchCtrl.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, color: AppTheme.textMuted, size: 20),
                              onPressed: () {
                                _searchCtrl.clear();
                                _filterStations('');
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.search_outlined, color: AppTheme.neonCyan, size: 22),
                            tooltip: 'Search Location via Google Maps',
                            onPressed: () => _searchLocationWithGoogle(_searchCtrl.text),
                          ),
                        ],
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: _currentLocation != null
                        ? AppTheme.neonCyan.withOpacity(0.2)
                        : AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _currentLocation != null ? AppTheme.neonCyan : AppTheme.border,
                    ),
                  ),
                  child: IconButton(
                    icon: _isFetchingLocation
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.neonGreen),
                          )
                        : Icon(
                            Icons.my_location_rounded,
                            color: _currentLocation != null ? AppTheme.neonCyan : AppTheme.neonGreen,
                          ),
                    tooltip: 'Fetch Current GPS Location (Google Maps)',
                    onPressed: _isFetchingLocation ? null : _fetchCurrentLocation,
                  ),
                ),
              ],
            ),
          ),

          // Active Location Filter Banner (if GPS or area search active)
          if (_currentLocation != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.neonCyan.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.neonCyan.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.near_me_rounded, color: AppTheme.neonCyan, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Stations near: ${_currentLocationName ?? "Current Location"}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.neonCyan, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: _loadStations,
                    child: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),

          // Content Area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.neonGreen))
                : _isMapView
                    ? _buildMapView()
                    : _buildListView(),
          ),
        ],
      ),
      floatingActionButton: _isMapView
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.bgCard,
              foregroundColor: AppTheme.neonGreen,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.neonGreen),
              ),
              icon: _isFetchingLocation
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.neonGreen),
                    )
                  : const Icon(Icons.my_location_rounded),
              label: const Text('My Location', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: _isFetchingLocation ? null : _fetchCurrentLocation,
            )
          : null,
    );
  }

  Widget _buildListView() {
    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.ev_station_rounded, size: 64, color: AppTheme.textDim),
            const SizedBox(height: 12),
            Text(
              _stations.isEmpty
                  ? 'No stations found. Ensure backend is running.'
                  : 'No stations match your location search.',
              style: const TextStyle(color: AppTheme.textMuted),
            ),
            if (_stations.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ElevatedButton.icon(
                  onPressed: _loadStations,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry Connection'),
                ),
              ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStations,
      color: AppTheme.neonGreen,
      backgroundColor: AppTheme.bgCard,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _filtered.length,
        itemBuilder: (context, i) {
          final s = _filtered[i];
          final isFast = s.chargerPower >= 50.0;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: AppTheme.glassCardDecoration(glow: isFast),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => StationDetailScreen(station: s)),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isFast
                                ? AppTheme.neonCyan.withOpacity(0.12)
                                : AppTheme.neonGreen.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isFast ? AppTheme.neonCyan.withOpacity(0.4) : AppTheme.borderGlow,
                            ),
                          ),
                          child: Icon(
                            isFast ? Icons.bolt_rounded : Icons.electric_car_rounded,
                            color: isFast ? AppTheme.neonCyan : AppTheme.neonGreen,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (s.isIotHub)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  margin: const EdgeInsets.only(bottom: 4),
                                  decoration: BoxDecoration(
                                    color: (s.isIotActive ? AppTheme.neonGreen : Colors.redAccent).withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: s.isIotActive ? AppTheme.neonGreen : Colors.redAccent),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.circle, size: 7, color: s.isIotActive ? AppTheme.neonGreen : Colors.redAccent),
                                      const SizedBox(width: 4),
                                      Text(
                                        s.isIotActive ? 'ESP32 LIVE (Active)' : 'IoT: Not Available',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          color: s.isIotActive ? AppTheme.neonGreen : Colors.redAccent,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Text(
                                s.stationName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textMain,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                s.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: s.isIotHub && !s.isIotActive
                                ? Colors.red.withOpacity(0.12)
                                : (s.availableSlots > 0
                                    ? AppTheme.neonGreen.withOpacity(0.12)
                                    : Colors.red.withOpacity(0.12)),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: s.isIotHub && !s.isIotActive
                                  ? Colors.redAccent
                                  : (s.availableSlots > 0 ? AppTheme.neonGreen : Colors.red),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            s.isIotHub && !s.isIotActive
                                ? 'Not Available'
                                : '${s.availableSlots}/${s.totalSlots} Slots',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: s.isIotHub && !s.isIotActive
                                  ? Colors.redAccent
                                  : (s.availableSlots > 0 ? AppTheme.neonGreen : Colors.redAccent),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: AppTheme.border),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.flash_on_rounded, size: 16, color: AppTheme.neonGreen),
                            const SizedBox(width: 4),
                            Text(
                              '${s.chargerPower.toStringAsFixed(0)} kW (${s.chargerType})',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMain),
                            ),
                          ],
                        ),
                        // Distance indicator (when GPS or area search active)
                        if (s.distanceText != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.neonCyan.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.near_me_rounded, size: 12, color: AppTheme.neonCyan),
                                const SizedBox(width: 3),
                                Text(
                                  s.distanceText!,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.neonCyan),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          children: [
                            const Icon(Icons.currency_rupee_rounded, size: 16, color: AppTheme.neonCyan),
                            Text(
                              '${s.pricePerKwh.toStringAsFixed(1)} / kWh',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.neonCyan),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMapView() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentLocation ??
            (_filtered.isNotEmpty
                ? LatLng(_filtered.first.latitude, _filtered.first.longitude)
                : _center),
        initialZoom: _currentLocation != null ? 13.5 : 12.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.evon.charging',
        ),
        MarkerLayer(
          markers: [
            // User Current Location Pulse Marker
            if (_currentLocation != null)
              Marker(
                point: _currentLocation!,
                width: 60,
                height: 60,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppTheme.neonCyan.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppTheme.neonCyan,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.neonCyan.withOpacity(0.8),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.my_location, size: 14, color: Color(0xFF0A0E17)),
                    ),
                  ],
                ),
              ),

            // Station Pins
            ..._filtered.map((s) {
              return Marker(
                point: LatLng(s.latitude, s.longitude),
                width: 48,
                height: 48,
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => StationDetailScreen(station: s)),
                    );
                  },
                  child: Tooltip(
                    message: '${s.stationName}\n${s.isIotHub ? (s.isIotActive ? "🟢 ESP32 LIVE (Active)\n" : "⚠️ ESP32 (Not Available)\n") : ""}${s.availableSlots}/${s.totalSlots} slots free${s.distanceText != null ? "\n${s.distanceText} away" : ""}',
                    child: Container(
                      decoration: BoxDecoration(
                        color: s.isIotHub
                            ? (s.isIotActive
                                ? (s.availableSlots > 0 ? AppTheme.neonCyan : Colors.orange)
                                : Colors.redAccent)
                            : (s.availableSlots > 0 ? AppTheme.neonGreen : Colors.red),
                        shape: BoxShape.circle,
                        border: s.isIotHub
                            ? Border.all(
                                color: s.isIotActive ? AppTheme.neonGreen : Colors.redAccent,
                                width: 2.5,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: (s.isIotHub
                                    ? (s.isIotActive ? AppTheme.neonCyan : Colors.redAccent)
                                    : (s.availableSlots > 0 ? AppTheme.neonGreen : Colors.red))
                                .withOpacity(0.6),
                            blurRadius: s.isIotHub ? 14 : 10,
                            spreadRadius: s.isIotHub ? 3 : 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        s.isIotHub ? Icons.sensors_rounded : Icons.ev_station_rounded,
                        color: const Color(0xFF0A0E17),
                        size: s.isIotHub ? 28 : 26,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }
}
