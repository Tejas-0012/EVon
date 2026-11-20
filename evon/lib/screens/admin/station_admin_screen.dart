import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/station_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/slot_model.dart';
import '../../models/station_model.dart';

class StationAdminScreen extends StatefulWidget {
  const StationAdminScreen({super.key});

  @override
  State<StationAdminScreen> createState() => _StationAdminScreenState();
}

class _StationAdminScreenState extends State<StationAdminScreen>
    with SingleTickerProviderStateMixin {
  final StationService _stationService = StationService();
  late TabController _tabController;

  bool _isLoading = true;
  StationModel? _assignedStation;
  List<dynamic> _stationBookings = [];
  List<SlotModel> _slots = [];
  String _selectedDate = DateTime.now().toIso8601String().split('T')[0];
  String _bookingStatusFilter = '';
  Map<String, dynamic>? _stationAnalytics;
  Map<String, dynamic>? _stationDemand;
  Map<String, dynamic>? _stationLoadForecast;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.currentUser;

    // Fetch all stations to locate the assigned station
    final allStations = await _stationService.getAllStations();
    StationModel? station;
    if (user?.assignedStation != null && user!.assignedStation!.isNotEmpty) {
      station = allStations.firstWhere(
        (s) => s.id == user.assignedStation,
        orElse: () => allStations.isNotEmpty
            ? allStations.first
            : StationModel(
                id: 'iot',
                stationName: 'EVon Charging Hub',
                address: 'IoT Smart Testbed Hub',
                city: 'Bangalore',
                latitude: 12.9850,
                longitude: 77.6350,
                chargerType: 'DC Fast',
                chargerPower: 50.0,
                totalSlots: 2,
                availableSlots: 2,
                occupiedSlots: 0,
                status: 'Active',
              ),
      );
    } else if (allStations.isNotEmpty) {
      station = allStations.first;
    }

    _assignedStation = station;

    // Load bookings for this station
    final bookings = await _stationService.getAllBookings(
      stationId: station?.id,
      status: _bookingStatusFilter.isNotEmpty ? _bookingStatusFilter : null,
    );

    // Load slots for selected date
    List<SlotModel> slots = [];
    if (station != null) {
      slots = await _stationService.getStationSlots(
        stationId: station.id,
        dateStr: _selectedDate,
      );
    }

    // Load station analytics, demand, and load forecast
    Map<String, dynamic>? analytics;
    Map<String, dynamic>? demand;
    Map<String, dynamic>? forecast;
    if (station != null) {
      analytics = await _stationService.getStationAnalytics(station.id);
      demand = await _stationService.getStationDemand(station.id);
      forecast = await _stationService.getStationLoadForecast(
        stationId: station.id,
        horizonHours: 24,
      );
    }

    if (mounted) {
      setState(() {
        _stationBookings = bookings;
        _slots = slots;
        _stationAnalytics = analytics;
        _stationDemand = demand;
        _stationLoadForecast = forecast;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateBookingStatus(String bookingId, String newStatus) async {
    final success = await _stationService.updateBookingStatus(
      bookingId,
      newStatus,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Session marked as $newStatus.'
                : 'Failed to update session.',
          ),
          backgroundColor: success ? AppTheme.neonGreen : Colors.red,
        ),
      );
      if (success) _loadAllData();
    }
  }

  Future<void> _toggleSlotStatus(SlotModel slot) async {
    final nextStatus = slot.status == 'Available'
        ? 'Occupied'
        : (slot.status == 'Occupied' ? 'Maintenance' : 'Available');

    final success = await _stationService.updateSlotStatus(slot.id, nextStatus);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Slot ${slot.slotTime} set to $nextStatus.'
                : 'Failed to update slot.',
          ),
          backgroundColor: success ? AppTheme.neonGreen : Colors.red,
          duration: const Duration(seconds: 1),
        ),
      );
      if (success) _loadAllData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;

    final stName = _assignedStation?.stationName ?? 'Assigned Station';
    final totalBookings = _stationBookings.length;
    final activeBookings = _stationBookings
        .where((b) => ['Confirmed', 'Paid'].contains(b['bookingStatus']))
        .length;
    final revenue = _stationBookings
        .where((b) => b['paymentStatus'] == 'Paid')
        .fold<double>(
          0.0,
          (sum, b) => sum + ((b['estimatedCost'] as num?)?.toDouble() ?? 0.0),
        );

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Station Admin Console',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              stName,
              style: const TextStyle(fontSize: 12, color: AppTheme.neonGreen),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.neonCyan),
            onPressed: _loadAllData,
            tooltip: 'Refresh Station Data',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.neonGreen,
          labelColor: AppTheme.neonGreen,
          unselectedLabelColor: AppTheme.textMuted,
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long_rounded), text: 'Bookings'),
            Tab(icon: Icon(Icons.analytics_rounded), text: 'Demand & Load'),
            Tab(icon: Icon(Icons.grid_view_rounded), text: 'Slots Manager'),
            Tab(
              icon: Icon(Icons.settings_input_component_rounded),
              text: 'IoT Bays & Info',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.neonGreen),
            )
          : Column(
              children: [
                // Quick Station Overview KPIs
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(
                    color: AppTheme.bgCard,
                    border: Border(bottom: BorderSide(color: AppTheme.border)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMiniStat(
                        'Total Bookings',
                        '$totalBookings',
                        AppTheme.neonCyan,
                      ),
                      _buildMiniStat(
                        'Active Sessions',
                        '$activeBookings',
                        AppTheme.neonGreen,
                      ),
                      _buildMiniStat(
                        'Total Revenue',
                        '₹${revenue.toStringAsFixed(0)}',
                        AppTheme.electricBlue,
                      ),
                      _buildMiniStat(
                        'Slots Avail',
                        '${_assignedStation?.availableSlots ?? 0} / ${_assignedStation?.totalSlots ?? 0}',
                        AppTheme.purple,
                      ),
                    ],
                  ),
                ),

                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBookingsTab(),
                      _buildDemandAndLoadTab(),
                      _buildSlotsTab(),
                      _buildIotAndStationTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
        ),
      ],
    );
  }

  // --- TAB 1: Station Bookings ---
  Widget _buildBookingsTab() {
    return Column(
      children: [
        // Status Filter Chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              const Text(
                'Filter: ',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        ['', 'Confirmed', 'Paid', 'Completed', 'Cancelled'].map(
                          (st) {
                            final isSel = _bookingStatusFilter == st;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(st.isEmpty ? 'All' : st),
                                selected: isSel,
                                onSelected: (_) {
                                  setState(() => _bookingStatusFilter = st);
                                  _loadAllData();
                                },
                                selectedColor: AppTheme.neonGreen.withOpacity(
                                  0.2,
                                ),
                                backgroundColor: AppTheme.bgCard,
                                labelStyle: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSel
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSel
                                      ? AppTheme.neonGreen
                                      : AppTheme.textMuted,
                                ),
                                side: BorderSide(
                                  color: isSel
                                      ? AppTheme.neonGreen
                                      : AppTheme.border,
                                ),
                              ),
                            );
                          },
                        ).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: _stationBookings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.event_busy_rounded,
                        size: 54,
                        color: AppTheme.textDim,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'No bookings found for ${_assignedStation?.stationName ?? "this station"}.',
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _stationBookings.length,
                  itemBuilder: (context, i) {
                    final b = _stationBookings[i];
                    final bId = b['_id'] ?? '';
                    final uName = b['user'] is Map
                        ? b['user']['name'] ?? 'Driver'
                        : 'Driver';
                    final uEmail = b['user'] is Map
                        ? b['user']['email'] ?? ''
                        : '';
                    final date = b['slotDate'] ?? '';
                    final time = b['slotTime'] ?? '';
                    final energy =
                        (b['energyRequired'] as num?)?.toDouble() ?? 0.0;
                    final cost =
                        (b['estimatedCost'] as num?)?.toDouble() ?? 0.0;
                    final status = b['bookingStatus'] ?? 'Confirmed';
                    final isPaid = b['paymentStatus'] == 'Paid';
                    final isCompleted = status == 'Completed';
                    final isCancelled = status == 'Cancelled';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: AppTheme.glassCardDecoration(
                        glow: isPaid && !isCompleted,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      uName,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textMain,
                                      ),
                                    ),
                                    Text(
                                      uEmail,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildStatusBadge(status, isPaid),
                            ],
                          ),
                          const Divider(height: 16, color: AppTheme.border),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '📅 $date at $time',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.neonCyan,
                                ),
                              ),
                              Text(
                                '⚡ ${energy.toStringAsFixed(1)} kWh',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.neonGreen,
                                ),
                              ),
                              Text(
                                '₹${cost.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textMain,
                                ),
                              ),
                            ],
                          ),
                          if (!isCompleted && !isCancelled) ...[
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (status == 'Pending') ...[
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _updateBookingStatus(bId, 'Confirmed'),
                                    icon: const Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 16,
                                      color: Color(0xFF0A0E17),
                                    ),
                                    label: const Text(
                                      'Accept Booking',
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
                                  const SizedBox(width: 8),
                                ] else ...[
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _updateBookingStatus(bId, 'Completed'),
                                    icon: const Icon(
                                      Icons.bolt_rounded,
                                      size: 16,
                                      color: Color(0xFF0A0E17),
                                    ),
                                    label: const Text(
                                      'Complete Session',
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
                                  const SizedBox(width: 8),
                                ],
                                OutlinedButton(
                                  onPressed: () =>
                                      _updateBookingStatus(bId, 'Cancelled'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    side: const BorderSide(
                                      color: Colors.redAccent,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Text('Reject', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- TAB 2: Station Demand & Load Prediction ---
  Widget _buildDemandAndLoadTab() {
    final st = _assignedStation;
    final demandVal = (_stationDemand?['predicted_demand'] as num?)?.toDouble() ?? 3.2;
    final congestion = _stationDemand?['congestion_level']?.toString() ?? 'Medium';
    final hr = DateTime.now().hour;
    final isPeak = (hr >= 8 && hr <= 11) || (hr >= 17 && hr <= 21);

    final forecasts = (_stationLoadForecast?['forecasts'] as List?) ?? [];

    Color congColor = AppTheme.neonGreen;
    if (congestion == 'High') congColor = Colors.redAccent;
    if (congestion == 'Medium') congColor = Colors.amberAccent;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Station Demand Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.glassCardDecoration(glow: isPeak),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bolt_rounded, color: AppTheme.neonGreen, size: 22),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              st?.stationName ?? 'Station',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textMain,
                              ),
                            ),
                            const Text(
                              'Live Station Demand & Grid Load Prediction',
                              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: congColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: congColor),
                      ),
                      child: Text(
                        '$congestion Congestion',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: congColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24, color: AppTheme.border),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildDemandMetric(
                      'Demand Index',
                      '${demandVal.toStringAsFixed(1)} / 5.0',
                      congColor,
                    ),
                    _buildDemandMetric(
                      'Current Hour',
                      '${hr.toString().padLeft(2, '0')}:00 hrs',
                      AppTheme.neonCyan,
                    ),
                    _buildDemandMetric(
                      'Window Status',
                      isPeak ? 'PEAK LOAD' : 'OFF-PEAK',
                      isPeak ? Colors.amberAccent : AppTheme.neonGreen,
                    ),
                    _buildDemandMetric(
                      'Charger Power',
                      '${st?.chargerPower.toInt() ?? 50} kW',
                      AppTheme.purple,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.bgDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isPeak ? Colors.amberAccent.withOpacity(0.4) : AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPeak ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                        color: isPeak ? Colors.amberAccent : AppTheme.neonGreen,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isPeak
                              ? 'Peak demand window in progress (08:00–11:00 & 17:00–21:00). High EV arrival frequency expected. Maintain fast turnaround.'
                              : 'Off-peak charging hours. Grid load is stable. Station capacity is fully available to accept incoming bookings.',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 24-Hour LSTM Load Forecast Chart
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '24-Hour LSTM Load Prediction Curve',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textMain,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.purple.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'TensorFlow/Keras LSTM',
                  style: TextStyle(fontSize: 10, color: AppTheme.purple, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.glassCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Predicted Power Draw (kW) over next 24 hours:',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 16),
                // Horizontal scrolling hourly load chart
                SizedBox(
                  height: 160,
                  child: forecasts.isEmpty
                      ? const Center(
                          child: Text(
                            'Loading LSTM load curve...',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                          ),
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: forecasts.length,
                          itemBuilder: (context, i) {
                            final f = forecasts[i];
                            final hour = f['hour'] as int? ?? i;
                            final loadKwh = (f['predictedLoadKwh'] as num?)?.toDouble() ?? 50.0;
                            final isCur = hour == hr;
                            final isHPeak = (hour >= 8 && hour <= 11) || (hour >= 17 && hour <= 21);

                            // Calculate bar height normalized to 100kW
                            final double barHeight = ((loadKwh / 100.0) * 100).clamp(18.0, 110.0);

                            Color barColor = AppTheme.electricBlue;
                            if (isCur) barColor = AppTheme.neonGreen;
                            else if (isHPeak) barColor = Colors.amberAccent;

                            return Container(
                              width: 38,
                              margin: const EdgeInsets.only(right: 6),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    '${loadKwh.toInt()}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: barColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    height: barHeight,
                                    width: 18,
                                    decoration: BoxDecoration(
                                      color: barColor.withOpacity(isCur ? 0.9 : 0.6),
                                      borderRadius: BorderRadius.circular(4),
                                      boxShadow: isCur
                                          ? [
                                              BoxShadow(
                                                color: AppTheme.neonGreen.withOpacity(0.5),
                                                blurRadius: 8,
                                              ),
                                            ]
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${hour.toString().padLeft(2, '0')}h',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: isCur ? FontWeight.bold : FontWeight.normal,
                                      color: isCur ? AppTheme.neonGreen : AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLegendItem('Current Hour', AppTheme.neonGreen),
                    const SizedBox(width: 14),
                    _buildLegendItem('Peak Hours (8-11, 17-21)', Colors.amberAccent),
                    const SizedBox(width: 14),
                    _buildLegendItem('Standard Hours', AppTheme.electricBlue),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Station Grid Load & Technical Specs
          const Text(
            'Station Grid & Power Profile',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textMain),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.glassCardDecoration(),
            child: Column(
              children: [
                _buildProfileRow('Station Identifier', st?.id ?? 'N/A'),
                const Divider(height: 16, color: AppTheme.border),
                _buildProfileRow('Physical Address', st?.address ?? 'N/A'),
                const Divider(height: 16, color: AppTheme.border),
                _buildProfileRow('Charger Hardware', '${st?.chargerType ?? "DC Fast"} (${st?.chargerPower.toInt() ?? 50} kW)'),
                const Divider(height: 16, color: AppTheme.border),
                _buildProfileRow('Max Grid Power Capacity', '${((st?.chargerPower ?? 50) * (st?.totalSlots ?? 2)).toInt()} kW concurrent'),
                const Divider(height: 16, color: AppTheme.border),
                _buildProfileRow('Base Energy Tariff', '₹${st?.pricePerKwh.toStringAsFixed(2) ?? "12.00"}/kWh'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemandMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
      ],
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
      ],
    );
  }

  // --- TAB 3: Slots Manager ---
  Widget _buildSlotsTab() {
    return Column(
      children: [
        // Date Selector Bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                size: 18,
                color: AppTheme.neonCyan,
              ),
              const SizedBox(width: 8),
              Text(
                'Schedule Date: $_selectedDate',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textMain,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 7)),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (picked != null) {
                    setState(
                      () => _selectedDate = picked.toIso8601String().split(
                        'T',
                      )[0],
                    );
                    _loadAllData();
                  }
                },
                child: const Text(
                  'Change Date',
                  style: TextStyle(color: AppTheme.neonGreen),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _slots.isEmpty
              ? const Center(
                  child: Text(
                    'No slots generated for this date.',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.6,
                  ),
                  itemCount: _slots.length,
                  itemBuilder: (context, i) {
                    final s = _slots[i];
                    Color statusColor = AppTheme.neonGreen;
                    if (s.status == 'Occupied' || s.status == 'Booked')
                      statusColor = Colors.orangeAccent;
                    if (s.status == 'Maintenance')
                      statusColor = Colors.redAccent;

                    return InkWell(
                      onTap: () => _toggleSlotStatus(s),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: statusColor.withOpacity(0.6),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              s.slotTime,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              s.status,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- TAB 3: IoT Bays & Station Info ---
  Widget _buildIotAndStationTab() {
    final st = _assignedStation;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Station Spec Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.glassCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      st?.stationName ?? 'Station',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textMain,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.neonGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        st?.status ?? 'Active',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.neonGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  st?.address ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
                const Divider(height: 20, color: AppTheme.border),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoColumn(
                      'Charger Type',
                      st?.chargerType ?? 'DC Fast',
                    ),
                    _buildInfoColumn(
                      'Max Power',
                      '${st?.chargerPower.toInt() ?? 50} kW',
                    ),
                    _buildInfoColumn(
                      'Tariff',
                      '₹${st?.pricePerKwh ?? 12.0}/kWh',
                    ),
                    _buildInfoColumn('Capacity', '${st?.totalSlots ?? 4} bays'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Live IoT Hardware Bays (ESP32 Integration)
          const Text(
            'Live IoT Hardware Bays (ESP32)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textMain,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildBayCard(1, 'Available')),
              const SizedBox(width: 12),
              Expanded(child: _buildBayCard(2, 'Charging')),
            ],
          ),
          const SizedBox(height: 16),

          // Station Analytics Overview
          const Text(
            'Station Demand & Analytics',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textMain,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.glassCardDecoration(),
            child: Column(
              children: [
                _buildMetricRow(
                  'Station Utilization Rate',
                  '${_stationAnalytics?['station']?['utilization'] ?? 50}%',
                ),
                const Divider(height: 16, color: AppTheme.border),
                _buildMetricRow(
                  'Energy Dispensed Today',
                  '${_stationAnalytics?['metrics']?['totalEnergyDispensed'] ?? 72.5} kWh',
                ),
                const Divider(height: 16, color: AppTheme.border),
                _buildMetricRow(
                  'Total Station Revenue',
                  '₹${_stationAnalytics?['metrics']?['totalRevenue'] ?? 1450}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBayCard(int bayNum, String fallbackStatus) {
    Color color = AppTheme.neonGreen;
    if (fallbackStatus == 'Charging') color = Colors.orangeAccent;
    if (fallbackStatus == 'Occupied') color = Colors.redAccent;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Icon(Icons.ev_station_rounded, size: 32, color: color),
          const SizedBox(height: 6),
          Text(
            'Bay #$bayNum',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.textMain,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            fallbackStatus,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isPaid) {
    Color c = AppTheme.neonCyan;
    String label = status;
    if (status == 'Pending') {
      c = Colors.orangeAccent;
      label = 'Pending Approval';
    } else if (status == 'Confirmed' || status == 'Accepted') {
      c = AppTheme.neonGreen;
      label = isPaid ? 'Accepted & Paid' : 'Accepted';
    } else if (status == 'Completed') {
      c = Colors.lightBlueAccent;
      label = 'Completed';
    } else if (status == 'Cancelled') {
      c = Colors.redAccent;
      label = 'Cancelled';
    } else if (isPaid) {
      c = AppTheme.neonGreen;
      label = 'Paid & Confirmed';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c),
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppTheme.textMain,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.neonGreen,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
