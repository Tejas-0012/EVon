import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/station_model.dart';
import '../../core/services/station_service.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_theme.dart';
import '../stations/station_detail_screen.dart';

class RoutePlannerScreen extends StatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  State<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends State<RoutePlannerScreen> {
  final StationService _stationService = StationService();
  final LocationService _locationService = LocationService();
  final MapController _mapController = MapController();

  final _originCtrl = TextEditingController(text: 'Koramangala');
  final _destCtrl = TextEditingController(text: 'Hebbal');

  bool _isLoading = false;
  bool _isLocatingOrigin = false;

  // Autocomplete Suggestions
  List<LocationSuggestion> _originSuggestions = [];
  List<LocationSuggestion> _destSuggestions = [];
  Timer? _debounceOrigin;
  Timer? _debounceDest;

  // Battery & Range Parameters
  double _currentSoc = 35.0; // %
  final double _batteryCapacity = 40.5; // kWh (Nexon EV)
  double? _distanceKm = 18.5;

  List<StationModel> _recommendedStations = [];
  List<LatLng> _routePoints = [];
  String? _routeSummary;
  String? _durationText;
  String? _distanceText;

  static const List<String> _popularDestinations = [
    'Hebbal',
    'Whitefield',
    'Electronic City',
    'Airport (KIA)',
    'Indiranagar',
    'HSR Layout',
    'Malleshwaram',
    'Sarjapur Road',
  ];

  @override
  void initState() {
    super.initState();
    // Auto-search default route on launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchRoute();
    });
  }

  @override
  void dispose() {
    _originCtrl.dispose();
    _destCtrl.dispose();
    _debounceOrigin?.cancel();
    _debounceDest?.cancel();
    super.dispose();
  }

  // --- Range & Battery Analysis ---
  double get _usableKwh => (_currentSoc / 100.0) * _batteryCapacity;
  double get _estimatedRangeKm => _usableKwh * 6.5; // ~6.5 km per kWh standard

  String get _batterySignal {
    final dist = _distanceKm ?? 20.0;
    if (_estimatedRangeKm >= dist * 1.3) return 'GREEN';
    if (_estimatedRangeKm >= dist) return 'YELLOW';
    return 'RED';
  }

  Color get _signalColor {
    switch (_batterySignal) {
      case 'GREEN':
        return AppTheme.neonGreen;
      case 'YELLOW':
        return Colors.orangeAccent;
      case 'RED':
      default:
        return Colors.redAccent;
    }
  }

  String get _signalTitle {
    switch (_batterySignal) {
      case 'GREEN':
        return '🟢 Easily Continue';
      case 'YELLOW':
        return '🟡 Low Margin - Caution';
      case 'RED':
      default:
        return '🔴 Charge Stop Required!';
    }
  }

  String get _signalDescription {
    final dist = _distanceKm ?? 20.0;
    if (_batterySignal == 'GREEN') {
      final buffer = (_estimatedRangeKm - dist).toStringAsFixed(1);
      return 'Battery sufficient! Range (~${_estimatedRangeKm.toStringAsFixed(1)} km) easily covers this ${dist.toStringAsFixed(1)} km journey with a safe buffer of +$buffer km.';
    } else if (_batterySignal == 'YELLOW') {
      final buffer = (_estimatedRangeKm - dist).toStringAsFixed(1);
      return 'Tight battery margin! Range (~${_estimatedRangeKm.toStringAsFixed(1)} km) is very close to trip distance (${dist.toStringAsFixed(1)} km, only +$buffer km buffer). Consider topping up along the corridor.';
    } else {
      final deficit = (dist - _estimatedRangeKm).toStringAsFixed(1);
      return 'Critical: Battery insufficient! Estimated range (~${_estimatedRangeKm.toStringAsFixed(1)} km) will run out before destination (${dist.toStringAsFixed(1)} km, deficit: $deficit km). Reserve an en-route charger below!';
    }
  }

  // --- Autocomplete Handlers ---
  void _onOriginChanged(String val) {
    _debounceOrigin?.cancel();
    if (val.trim().isEmpty) {
      setState(() => _originSuggestions = []);
      return;
    }
    _debounceOrigin = Timer(const Duration(milliseconds: 200), () async {
      final suggestions = await _locationService.searchPlaces(val);
      if (mounted) setState(() => _originSuggestions = suggestions);
    });
  }

  void _onDestChanged(String val) {
    _debounceDest?.cancel();
    if (val.trim().isEmpty) {
      setState(() => _destSuggestions = []);
      return;
    }
    _debounceDest = Timer(const Duration(milliseconds: 200), () async {
      final suggestions = await _locationService.searchPlaces(val);
      if (mounted) setState(() => _destSuggestions = suggestions);
    });
  }

  /// 📍 Fetch device GPS location & reverse geocode via Google Maps
  Future<void> _useCurrentLocationAsOrigin() async {
    setState(() => _isLocatingOrigin = true);
    try {
      final pos = await _locationService.getCurrentPosition();
      final double lat = pos?.latitude ?? 12.9716;
      final double lng = pos?.longitude ?? 77.5946;

      final geo = await _locationService.reverseGeocode(lat, lng);
      if (!mounted) return;

      final locText = (geo?.area.isNotEmpty == true)
          ? '${geo!.area}, Bengaluru'
          : (geo?.formattedAddress ?? '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}');

      setState(() {
        _originCtrl.text = locText;
        _originSuggestions = [];
        _isLocatingOrigin = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📍 Origin set to GPS location: $locText'),
          backgroundColor: AppTheme.bgCard,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _searchRoute();
    } catch (_) {
      if (mounted) setState(() => _isLocatingOrigin = false);
    }
  }

  Future<void> _searchRoute() async {
    final orig = _originCtrl.text.trim();
    final dest = _destCtrl.text.trim();

    if (orig.isEmpty || dest.isEmpty) return;

    setState(() {
      _isLoading = true;
      _originSuggestions = [];
      _destSuggestions = [];
      _routeSummary = null;
    });

    final res = await _stationService.getRouteRecommendations(
      origin: orig,
      destination: dest,
      currentSoc: _currentSoc,
      batteryCapacity: _batteryCapacity,
    );

    if (!mounted) return;

    List<StationModel> stations = [];
    if (res['stations'] is List) {
      stations = (res['stations'] as List)
          .map((item) => StationModel.fromJson(item))
          .toList();
    }

    List<LatLng> points = [];
    if (res['routePoints'] is List) {
      for (final p in res['routePoints']) {
        if (p is List && p.length >= 2) {
          points.add(
            LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()),
          );
        }
      }
    }

    double? dist;
    if (res['distanceKm'] != null) {
      dist = (res['distanceKm'] as num).toDouble();
    } else if (res['distanceText'] != null) {
      dist = double.tryParse(res['distanceText'].toString().replaceAll(RegExp(r'[^0-9.]'), ''));
    }

    setState(() {
      _recommendedStations = stations;
      _routePoints = points;
      _distanceText = res['distanceText'];
      _durationText = res['durationText'];
      _distanceKm = dist ?? 20.0;
      final engine = res['routingEngine'] ?? 'Driving Engine';
      _routeSummary = (_distanceText != null && _distanceText!.isNotEmpty)
          ? 'Route: $_distanceText · $_durationText via $engine'
          : 'Corridor Route Navigation';
      _isLoading = false;
    });

    if (mounted && points.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          try {
            _mapController.move(points[points.length ~/ 2], 12.0);
          } catch (_) {
            // Safe fallback if unmounted
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text(
          'Smart Route & Battery Planner',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Route & Battery Planning Input Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.glassCardDecoration(glow: true),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Plan Your EV Journey',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMain,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Origin Field with Live Autocomplete
                  TextField(
                    controller: _originCtrl,
                    onChanged: _onOriginChanged,
                    style: const TextStyle(color: AppTheme.textMain),
                    decoration: InputDecoration(
                      labelText: 'Origin / Start Location',
                      prefixIcon: const Icon(
                        Icons.my_location_rounded,
                        color: AppTheme.neonGreen,
                      ),
                      suffixIcon: IconButton(
                        icon: _isLocatingOrigin
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.neonGreen),
                              )
                            : const Icon(Icons.gps_fixed_rounded, color: AppTheme.neonGreen),
                        tooltip: 'Use My GPS Location (Google Maps)',
                        onPressed: _isLocatingOrigin ? null : _useCurrentLocationAsOrigin,
                      ),
                    ),
                  ),

                  // Origin Autocomplete Suggestions Dropdown
                  if (_originSuggestions.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _buildSuggestionsList(_originSuggestions, (s) {
                      setState(() {
                        _originCtrl.text = s.name;
                        _originSuggestions = [];
                      });
                      _searchRoute();
                    }),
                  ],

                  const SizedBox(height: 14),

                  // Destination Field with Live Autocomplete
                  TextField(
                    controller: _destCtrl,
                    onChanged: _onDestChanged,
                    style: const TextStyle(color: AppTheme.textMain),
                    decoration: const InputDecoration(
                      labelText: 'Destination (e.g. Hebbal, Whitefield)',
                      prefixIcon: Icon(
                        Icons.location_on_rounded,
                        color: AppTheme.neonCyan,
                      ),
                    ),
                  ),

                  // Destination Autocomplete Suggestions Dropdown
                  if (_destSuggestions.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _buildSuggestionsList(_destSuggestions, (s) {
                      setState(() {
                        _destCtrl.text = s.name;
                        _destSuggestions = [];
                      });
                      _searchRoute();
                    }),
                  ],

                  const SizedBox(height: 12),

                  // Quick Destination Chips
                  const Text(
                    'Quick Destinations:',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _popularDestinations.map((dest) {
                      final isSelected = _destCtrl.text.toLowerCase() == dest.toLowerCase();
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _destCtrl.text = dest;
                            _destSuggestions = [];
                          });
                          _searchRoute();
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.neonCyan.withOpacity(0.2) : AppTheme.bgDark,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? AppTheme.neonCyan : AppTheme.border,
                            ),
                          ),
                          child: Text(
                            dest,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? AppTheme.neonCyan : AppTheme.textMuted,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const Divider(height: 24, color: AppTheme.border),

                  // Interactive Battery SoC Slider & Range Prediction
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.battery_charging_full_rounded, color: AppTheme.neonGreen, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Current Battery SoC: ${_currentSoc.toInt()}%',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textMain, fontSize: 13),
                          ),
                        ],
                      ),
                      Text(
                        'Est Range: ${_estimatedRangeKm.toStringAsFixed(1)} km',
                        style: TextStyle(fontWeight: FontWeight.bold, color: _signalColor, fontSize: 13),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: _signalColor,
                      inactiveTrackColor: AppTheme.border,
                      thumbColor: _signalColor,
                      overlayColor: _signalColor.withOpacity(0.2),
                    ),
                    child: Slider(
                      value: _currentSoc,
                      min: 10.0,
                      max: 100.0,
                      divisions: 18,
                      label: '${_currentSoc.toInt()}%',
                      onChanged: (val) {
                        setState(() => _currentSoc = val);
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Vehicle: Nexon EV (${_batteryCapacity} kWh pack)',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                      Text(
                        'Usable Energy: ${_usableKwh.toStringAsFixed(1)} kWh',
                        style: const TextStyle(fontSize: 11, color: AppTheme.neonCyan),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.neonGreen.withOpacity(0.3),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _searchRoute,
                      icon: const Icon(
                        Icons.alt_route_rounded,
                        color: Color(0xFF0A0E17),
                      ),
                      label: const Text(
                        'Analyze Journey & Route',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A0E17),
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: AppTheme.neonGreen),
                ),
              )
            else ...[
              // --- DYNAMIC COLOR SIGNAL BANNER ---
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _signalColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _signalColor.withOpacity(0.8), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: _signalColor.withOpacity(0.2),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _batterySignal == 'GREEN'
                              ? Icons.check_circle_rounded
                              : (_batterySignal == 'YELLOW' ? Icons.warning_amber_rounded : Icons.emergency_rounded),
                          color: _signalColor,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _signalTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _signalColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _signalColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${_currentSoc.toInt()}% SOC',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _signalColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _signalDescription,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textMain, height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Trip Distance: ${_distanceKm?.toStringAsFixed(1) ?? "18.5"} km', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                        Text('Battery Range: ${_estimatedRangeKm.toStringAsFixed(1)} km', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _signalColor)),
                      ],
                    ),
                  ],
                ),
              ),

              if (_routeSummary != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.route_rounded,
                        color: AppTheme.neonGreen,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _routeSummary!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.neonGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Interactive Route Map
              Container(
                height: 280,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: AppTheme.glassCardDecoration(glow: true),
                clipBehavior: Clip.antiAlias,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _routePoints.isNotEmpty
                        ? _routePoints.first
                        : const LatLng(12.9716, 77.5946),
                    initialZoom: 11.5,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.evon.charging',
                    ),
                    if (_routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            strokeWidth: 4.5,
                            color: AppTheme.neonGreen,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        // Recommended Station Pins along Route
                        ..._recommendedStations.map((s) {
                          return Marker(
                            point: LatLng(s.latitude, s.longitude),
                            width: 34,
                            height: 34,
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => StationDetailScreen(station: s),
                                  ),
                                );
                              },
                              child: Tooltip(
                                message: '${s.stationName} (${s.chargerPower} kW)\n${s.availableSlots} free slots',
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.neonCyan,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.neonCyan.withOpacity(0.5),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.ev_station_rounded,
                                    size: 20,
                                    color: Color(0xFF0A0E17),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),

                        // Origin Pin
                        if (_routePoints.isNotEmpty) ...[
                          Marker(
                            point: _routePoints.first,
                            width: 42,
                            height: 42,
                            child: Tooltip(
                              message: 'Start: ${_originCtrl.text}',
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.neonGreen,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.neonGreen.withOpacity(0.6),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.trip_origin_rounded,
                                  color: Color(0xFF0A0E17),
                                  size: 22,
                                ),
                              ),
                            ),
                          ),

                          // Destination Pin
                          Marker(
                            point: _routePoints.last,
                            width: 42,
                            height: 42,
                            child: Tooltip(
                              message: 'Destination: ${_destCtrl.text}',
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.redAccent.withOpacity(0.6),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.flag_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Section Header: En-Route Charging Hub Recommendations
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _batterySignal == 'RED'
                        ? '⚡ Recommended En-Route Charging Hubs'
                        : 'Corridor Charging Hubs',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _batterySignal == 'RED' ? Colors.redAccent : AppTheme.textMain,
                    ),
                  ),
                  Text(
                    '${_recommendedStations.length} available',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (_recommendedStations.isEmpty && _routeSummary != null)
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  decoration: AppTheme.glassCardDecoration(),
                  child: const Text(
                    'No corridor stations found for this query. Try major hubs like Koramangala, Hebbal, Indiranagar, Electronic City, or Whitefield.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recommendedStations.length,
                  itemBuilder: (context, i) {
                    final s = _recommendedStations[i];
                    final isPriorityStop = (_batterySignal == 'RED' || _batterySignal == 'YELLOW') && i == 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: AppTheme.glassCardDecoration(glow: isPriorityStop),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isPriorityStop)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _signalColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _signalColor),
                              ),
                              child: Text(
                                '★ OPTIMAL RECHARGE STOP ON YOUR ROUTE',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _signalColor),
                              ),
                            ),
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AppTheme.neonGreen.withOpacity(0.15),
                                child: const Icon(
                                  Icons.ev_station_rounded,
                                  color: AppTheme.neonGreen,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.stationName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppTheme.textMain,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${s.chargerPower.toInt()} kW ${s.chargerType} · ${s.availableSlots}/${s.totalSlots} slots free · ₹${s.pricePerKwh}/kWh',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 18, color: AppTheme.border),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => StationDetailScreen(station: s),
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.neonCyan,
                                  side: const BorderSide(color: AppTheme.neonCyan),
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: const Text('View Hub', style: TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => StationDetailScreen(station: s),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFF0A0E17)),
                                label: const Text(
                                  'Reserve Slot',
                                  style: TextStyle(
                                    color: Color(0xFF0A0E17),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.neonGreen,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsList(List<LocationSuggestion> list, Function(LocationSuggestion) onSelect) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.neonCyan.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Text(
              '📍 Matching Suggestions (tap to select):',
              style: TextStyle(fontSize: 10, color: AppTheme.neonCyan, fontWeight: FontWeight.bold),
            ),
          ),
          ...list.take(4).map((s) {
            return ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: const Icon(Icons.location_on_outlined, size: 16, color: AppTheme.neonGreen),
              title: Text(s.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
              subtitle: Text(
                s.formattedAddress,
                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => onSelect(s),
            );
          }),
        ],
      ),
    );
  }
}
