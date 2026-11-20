import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/station_service.dart';
import '../../core/services/booking_service.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/station_model.dart';
import '../../models/booking_model.dart';
import '../stations/station_detail_screen.dart';

class UserDashboardScreen extends StatefulWidget {
  final Function(int tabIndex)? onNavigateTab;

  const UserDashboardScreen({super.key, this.onNavigateTab});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  final StationService _stationService = StationService();
  final BookingService _bookingService = BookingService();
  final LocationService _locationService = LocationService();

  List<StationModel> _featuredStations = [];
  List<BookingModel> _recentBookings = [];
  bool _isLoading = true;
  String? _userArea;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    List<StationModel> stations = [];
    final pos = await _locationService.getCurrentPosition();
    if (pos != null) {
      final geo = await _locationService.reverseGeocode(pos.latitude, pos.longitude);
      _userArea = geo?.area.isNotEmpty == true ? geo!.area : 'Nearby';
      stations = await _stationService.getNearbyStations(
        lat: pos.latitude,
        lng: pos.longitude,
        maxDistanceKm: 25.0,
      );
    }

    if (stations.isEmpty) {
      stations = await _stationService.getAllStations();
    }

    final bookings = await _bookingService.getMyBookings();

    if (!mounted) return;
    setState(() {
      _featuredStations = stations.take(4).toList();
      _recentBookings = bookings.take(3).toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.bolt_rounded, color: AppTheme.neonGreen),
            const SizedBox(width: 6),
            ShaderMask(
              shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
              child: const Text(
                'EVon Portal',
                style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.neonCyan),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.neonGreen))
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              color: AppTheme.neonGreen,
              backgroundColor: AppTheme.bgCard,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header exactly like user_dashboard.html
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.neonGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: const Text(
                        'EV OWNER PORTAL',
                        style: TextStyle(
                          color: AppTheme.neonGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Text(
                          'Hello, ',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                        ),
                        ShaderMask(
                          shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                          child: Text(
                            user?.name ?? 'Driver',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                        ),
                        const Text(
                          '!',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 4 Stat Widgets matching original stat-widget
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatWidget(
                            value: '${user?.batteryCapacity.toInt() ?? 60} kWh',
                            label: 'Battery',
                            color: AppTheme.neonGreen,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatWidget(
                            value: '${_recentBookings.length}',
                            label: 'Bookings',
                            color: AppTheme.neonCyan,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatWidget(
                            value: '${_recentBookings.where((b) => !b.isCancelled).length}',
                            label: 'Active',
                            color: AppTheme.purple,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatWidget(
                            value: user?.vehicleType.split(' ').first ?? 'Car',
                            label: 'Vehicle',
                            color: AppTheme.electricBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Quick Actions matching quick-link-card
                    const Text(
                      'Quick Actions',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickActionCard(
                            icon: Icons.calendar_today_rounded,
                            title: 'Book Slot',
                            color: AppTheme.neonGreen,
                            onTap: () => widget.onNavigateTab?.call(1), // stations
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildQuickActionCard(
                            icon: Icons.ev_station_rounded,
                            title: 'Stations',
                            color: AppTheme.neonCyan,
                            onTap: () => widget.onNavigateTab?.call(1),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildQuickActionCard(
                            icon: Icons.alt_route_rounded,
                            title: 'Route',
                            color: AppTheme.electricBlue,
                            onTap: () => widget.onNavigateTab?.call(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildQuickActionCard(
                            icon: Icons.analytics_outlined,
                            title: 'Analytics',
                            color: AppTheme.purple,
                            onTap: () => widget.onNavigateTab?.call(4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Featured Available Stations matching station-preview
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.near_me_rounded, size: 18, color: AppTheme.neonCyan),
                            const SizedBox(width: 6),
                            Text(
                              _userArea != null ? 'Stations Near $_userArea' : 'Available Stations',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => widget.onNavigateTab?.call(1),
                          child: const Text(
                            'View All →',
                            style: TextStyle(color: AppTheme.neonGreen, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    ..._featuredStations.map((s) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: AppTheme.glassCardDecoration(),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => StationDetailScreen(station: s)),
                            );
                          },
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: s.availableSlots > 0 ? AppTheme.neonGreen : Colors.red,
                                  boxShadow: [
                                    BoxShadow(
                                      color: s.availableSlots > 0
                                          ? AppTheme.neonGreen.withOpacity(0.6)
                                          : Colors.red.withOpacity(0.6),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.stationName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textMain),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${s.distanceText != null ? "${s.distanceText} · " : ""}${s.chargerType} · ${s.chargerPower} kW · ${s.city}',
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.neonGreen.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppTheme.borderGlow),
                                ),
                                child: Text(
                                  '${s.availableSlots} free',
                                  style: const TextStyle(
                                    color: AppTheme.neonGreen,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),

                    const SizedBox(height: 20),

                    // Recent Bookings section matching user_dashboard.html
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Bookings',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                        ),
                        GestureDetector(
                          onTap: () => widget.onNavigateTab?.call(3),
                          child: const Text(
                            'History →',
                            style: TextStyle(color: AppTheme.neonCyan, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_recentBookings.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        alignment: Alignment.center,
                        decoration: AppTheme.glassCardDecoration(),
                        child: const Text('No recent bookings found.', style: TextStyle(color: AppTheme.textMuted)),
                      )
                    else
                      ..._recentBookings.map((b) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: AppTheme.glassCardDecoration(),
                          child: Row(
                            children: [
                              const Icon(Icons.history_rounded, color: AppTheme.neonCyan, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      b.stationName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textMain),
                                    ),
                                    Text(
                                      '${b.energyRequired.toStringAsFixed(1)} kWh · ${b.status}',
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '₹${b.estimatedCost.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: AppTheme.neonGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatWidget({required String value, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: AppTheme.glassCardDecoration(),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: AppTheme.glassCardDecoration(),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMain),
            ),
          ],
        ),
      ),
    );
  }
}
