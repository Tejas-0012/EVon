import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/station_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/station_model.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> with SingleTickerProviderStateMixin {
  final StationService _stationService = StationService();
  final AnalyticsService _analyticsService = AnalyticsService();
  late TabController _tabController;

  bool _isLoading = true;
  Map<String, dynamic>? _overviewMetrics;
  List<dynamic> _allBookings = [];
  List<StationModel> _stations = [];
  List<dynamic> _stationAdmins = [];
  List<Map<String, dynamic>> _loadForecast = [];

  String _selectedStationFilter = '';
  String _selectedStatusFilter = '';

  // ── Task 3: date range filter ──────────────────────────────────────────────
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // Task 1: 3→4
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final metrics = await _analyticsService.getAdminOverview();
    final forecast = await _analyticsService.getLoadForecast();
    final stations = await _stationService.getAllStations();
    final admins = await _stationService.getStationAdmins();
    final bookings = await _stationService.getAllBookings(
      stationId: _selectedStationFilter.isNotEmpty ? _selectedStationFilter : null,
      status: _selectedStatusFilter.isNotEmpty ? _selectedStatusFilter : null,
    );

    if (mounted) {
      setState(() {
        _overviewMetrics = metrics;
        _loadForecast = forecast;
        _stations = stations;
        _stationAdmins = admins;
        _allBookings = bookings;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateBookingStatus(String bookingId, String newStatus) async {
    final success = await _stationService.updateBookingStatus(bookingId, newStatus);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Booking marked as $newStatus.' : 'Failed to update booking.'),
          backgroundColor: success ? AppTheme.neonGreen : Colors.red,
        ),
      );
      if (success) _loadData();
    }
  }

  // ── Derived / filtered bookings ──────────────────────────────────────────
  List<dynamic> get _filteredBookings {
    if (_dateRange == null) return _allBookings;
    return _allBookings.where((b) {
      final raw = b['slotDate']?.toString() ?? '';
      if (raw.isEmpty) return true;
      try {
        final date = DateTime.parse(raw.split('T').first);
        return !date.isBefore(_dateRange!.start) && !date.isAfter(_dateRange!.end);
      } catch (_) {
        return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Super Administrator', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Central Network Hub & Station Management', style: TextStyle(fontSize: 11, color: AppTheme.purple)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.neonCyan),
            onPressed: _loadData,
            tooltip: 'Refresh Platform Data',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.purple,
          labelColor: AppTheme.purple,
          unselectedLabelColor: AppTheme.textMuted,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long_rounded), text: 'All Bookings'),
            Tab(icon: Icon(Icons.admin_panel_settings_rounded), text: 'Station Admins'),
            Tab(icon: Icon(Icons.analytics_rounded), text: 'Network & ML'),
            Tab(icon: Icon(Icons.people_rounded), text: 'Users'), // Task 1
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.purple))
          : Column(
              children: [
                // Platform KPI Metrics Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: AppTheme.bgCard,
                    border: Border(bottom: BorderSide(color: AppTheme.border)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildPlatformKpi('Active Stations', '${_overviewMetrics?['totalStations'] ?? _stations.length}', AppTheme.neonGreen),
                      _buildPlatformKpi('Total Users', '${_overviewMetrics?['totalUsers'] ?? 12}', AppTheme.neonCyan),
                      _buildPlatformKpi('Platform Bookings', '${_overviewMetrics?['totalBookings'] ?? _allBookings.length}', AppTheme.purple),
                      _buildPlatformKpi('Platform Revenue', '₹${(_overviewMetrics?['totalRevenue'] as num?)?.toStringAsFixed(0) ?? "4,850"}', AppTheme.electricBlue),
                    ],
                  ),
                ),

                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAllBookingsTab(),
                      _buildStationAdminsTab(),
                      _buildNetworkMlTab(),
                      _buildUsersTab(), // Task 1
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPlatformKpi(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 1: Platform-wide Bookings
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildAllBookingsTab() {
    final bookings = _filteredBookings;

    // ── Donut chart counts (Task 2) ──────────────────────────────────────────
    int confirmed = 0, cancelled = 0, completed = 0, pending = 0;
    double totalRevenue = 0;
    for (final b in _allBookings) {
      final s = (b['bookingStatus'] ?? '').toString();
      final cost = (b['estimatedCost'] as num?)?.toDouble() ?? 0;
      if (s == 'Confirmed' || s == 'Paid' || s == 'Accepted') {
        confirmed++;
        totalRevenue += cost;
      } else if (s == 'Cancelled') {
        cancelled++;
      } else if (s == 'Completed') {
        completed++;
        totalRevenue += cost;
      } else {
        pending++;
      }
    }
    final total = confirmed + cancelled + completed + pending;
    final avgCost = total > 0
        ? (_allBookings.fold<double>(0, (s, b) => s + ((b['estimatedCost'] as num?)?.toDouble() ?? 0)) / total)
        : 0.0;

    return Column(
      children: [
        // ── Task 2: Donut chart + stat badges ────────────────────────────────
        if (_allBookings.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: AppTheme.glassCardDecoration(),
              child: Row(
                children: [
                  // Donut chart
                  SizedBox(
                    height: 160,
                    width: 160,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 42,
                        sections: [
                          if (confirmed > 0)
                            PieChartSectionData(
                              value: confirmed.toDouble(),
                              color: const Color(0xFF00FFAA),
                              title: '$confirmed',
                              titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
                              radius: 32,
                            ),
                          if (cancelled > 0)
                            PieChartSectionData(
                              value: cancelled.toDouble(),
                              color: Colors.redAccent,
                              title: '$cancelled',
                              titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                              radius: 32,
                            ),
                          if (completed > 0)
                            PieChartSectionData(
                              value: completed.toDouble(),
                              color: Colors.lightBlue,
                              title: '$completed',
                              titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                              radius: 32,
                            ),
                          if (pending > 0)
                            PieChartSectionData(
                              value: pending.toDouble(),
                              color: Colors.orange,
                              title: '$pending',
                              titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                              radius: 32,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Stat badges
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildMiniStatBadge('Confirmed', '$confirmed', const Color(0xFF00FFAA)),
                        const SizedBox(height: 8),
                        _buildMiniStatBadge('Cancelled', '$cancelled', Colors.redAccent),
                        const SizedBox(height: 8),
                        _buildMiniStatBadge('Revenue', '₹${totalRevenue.toStringAsFixed(0)}', AppTheme.electricBlue),
                        const SizedBox(height: 8),
                        _buildMiniStatBadge('Avg Cost', '₹${avgCost.toStringAsFixed(0)}', AppTheme.purple),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Task 3: Date range filter chip ────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              const Icon(Icons.date_range_rounded, size: 16, color: AppTheme.textMuted),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDateRange: _dateRange,
                    builder: (ctx, child) => Theme(
                      data: Theme.of(ctx).copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: AppTheme.purple,
                          onPrimary: Colors.white,
                          surface: AppTheme.bgCard,
                          onSurface: AppTheme.textMain,
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) setState(() => _dateRange = picked);
                },
                child: Chip(
                  avatar: const Icon(Icons.filter_alt_rounded, size: 14, color: AppTheme.purple),
                  label: Text(
                    _dateRange == null
                        ? 'Filter by Date'
                        : '${_formatDate(_dateRange!.start)} – ${_formatDate(_dateRange!.end)}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMain),
                  ),
                  backgroundColor: AppTheme.bgCard,
                  side: BorderSide(color: _dateRange != null ? AppTheme.purple : AppTheme.border),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              if (_dateRange != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => setState(() => _dateRange = null),
                  child: const Chip(
                    label: Text('Clear', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                    backgroundColor: AppTheme.bgCard,
                    side: BorderSide(color: Colors.redAccent),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
              const Spacer(),
              Text('${bookings.length} bookings', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            ],
          ),
        ),

        // ── Station + Status filter row ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              // Station dropdown
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedStationFilter,
                      isExpanded: true,
                      dropdownColor: AppTheme.bgCard,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMain),
                      items: [
                        const DropdownMenuItem(value: '', child: Text('All Stations')),
                        ..._stations.map((s) => DropdownMenuItem(value: s.id, child: Text(s.stationName, overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedStationFilter = val ?? '');
                        _loadData();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Status dropdown
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedStatusFilter,
                      isExpanded: true,
                      dropdownColor: AppTheme.bgCard,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMain),
                      items: const [
                        DropdownMenuItem(value: '', child: Text('All Status')),
                        DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                        DropdownMenuItem(value: 'Confirmed', child: Text('Confirmed')),
                        DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                        DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                        DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedStatusFilter = val ?? '');
                        _loadData();
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: bookings.isEmpty
              ? const Center(
                  child: Text('No bookings match the selected filters.', style: TextStyle(color: AppTheme.textMuted)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: bookings.length,
                  itemBuilder: (context, i) {
                    final b = bookings[i];
                    final bId = b['_id'] ?? '';
                    final stName = b['station'] is Map ? b['station']['stationName'] ?? 'Station' : 'Station';
                    final uName = b['user'] is Map ? b['user']['name'] ?? 'Driver' : 'Driver';
                    final date = b['slotDate'] ?? '';
                    final time = b['slotTime'] ?? '';
                    final energy = (b['energyRequired'] as num?)?.toDouble() ?? 0.0;
                    final cost = (b['estimatedCost'] as num?)?.toDouble() ?? 0.0;
                    final status = b['bookingStatus'] ?? 'Confirmed';
                    final isPaid = b['paymentStatus'] == 'Paid';
                    final isCompleted = status == 'Completed';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: AppTheme.glassCardDecoration(glow: isPaid && !isCompleted),
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
                                      stName,
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                                    ),
                                    Text('Driver: $uName', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
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
                              Text('📅 $date at $time', style: const TextStyle(fontSize: 12, color: AppTheme.neonCyan)),
                              Text('⚡ ${energy.toStringAsFixed(1)} kWh', style: const TextStyle(fontSize: 12, color: AppTheme.neonGreen)),
                              Text('₹${cost.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                            ],
                          ),
                          if (!isCompleted && status != 'Cancelled') ...[
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (status == 'Pending') ...[
                                  OutlinedButton(
                                    onPressed: () => _updateBookingStatus(bId, 'Confirmed'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.neonGreen,
                                      side: const BorderSide(color: AppTheme.neonGreen),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    child: const Text('Accept Booking', style: TextStyle(fontSize: 11)),
                                  ),
                                  const SizedBox(width: 8),
                                ] else ...[
                                  OutlinedButton(
                                    onPressed: () => _updateBookingStatus(bId, 'Completed'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.neonGreen,
                                      side: const BorderSide(color: AppTheme.neonGreen),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    child: const Text('Mark Completed', style: TextStyle(fontSize: 11)),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                OutlinedButton(
                                  onPressed: () => _updateBookingStatus(bId, 'Cancelled'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    side: const BorderSide(color: Colors.redAccent),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Text('Cancel', style: TextStyle(fontSize: 11)),
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

  // Helper: mini stat badge for donut chart row (Task 2)
  Widget _buildMiniStatBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // Helper: format date for chip label (Task 3)
  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 2: Station Admins Directory
  // ════════════════════════════════════════════════════════════════════════════
  Future<void> _showCreateAdminDialog() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController(text: 'station123');
    final phoneCtrl = TextEditingController();
    String? selectedStationId = _stations.isNotEmpty ? _stations.first.id : null;
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.bgCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.purple),
              ),
              title: Row(
                children: const [
                  Icon(Icons.person_add_rounded, color: AppTheme.purple, size: 22),
                  SizedBox(width: 8),
                  Text('Create Station Admin', style: TextStyle(color: AppTheme.textMain, fontSize: 16)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Assign a dedicated Station Admin to manage a specific charging station.',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: AppTheme.textMain),
                      decoration: const InputDecoration(
                        labelText: 'Admin Full Name',
                        prefixIcon: Icon(Icons.badge_outlined, color: AppTheme.purple),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: AppTheme.textMain),
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined, color: AppTheme.purple),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passCtrl,
                      style: const TextStyle(color: AppTheme.textMain),
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline_rounded, color: AppTheme.purple),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: AppTheme.textMain),
                      decoration: const InputDecoration(
                        labelText: 'Phone (Optional)',
                        prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.purple),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Assign Charging Station *',
                      style: TextStyle(color: AppTheme.neonCyan, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.bgDark,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedStationId,
                          isExpanded: true,
                          dropdownColor: AppTheme.bgDark,
                          style: const TextStyle(color: AppTheme.textMain, fontSize: 13),
                          items: _stations.map((s) {
                            return DropdownMenuItem<String>(
                              value: s.id,
                              child: Text('${s.stationName} (${s.chargerPower.toInt()} kW)'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() => selectedStationId = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          final email = emailCtrl.text.trim();
                          final password = passCtrl.text.trim();
                          final phone = phoneCtrl.text.trim();

                          if (name.isEmpty || email.isEmpty || password.isEmpty || selectedStationId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please fill all required fields and select a station.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);
                          final res = await _stationService.createStationAdmin(
                            name: name,
                            email: email,
                            password: password,
                            phone: phone,
                            assignedStation: selectedStationId!,
                          );
                          setDialogState(() => isSubmitting = false);

                          if (ctx.mounted) Navigator.pop(ctx);

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res.message),
                                backgroundColor: res.success ? AppTheme.neonGreen : Colors.red,
                              ),
                            );
                            if (res.success) _loadData();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.purple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Create & Assign', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteStationAdmin(String adminId, String adminName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Colors.redAccent),
        ),
        title: const Text('Remove Station Admin?', style: TextStyle(color: AppTheme.textMain)),
        content: Text('Are you sure you want to remove "$adminName"? This admin will lose access to the assigned station.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete Admin', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ok = await _stationService.deleteStationAdmin(adminId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Station admin removed.' : 'Failed to delete station admin.'),
            backgroundColor: ok ? AppTheme.neonGreen : Colors.red,
          ),
        );
        if (ok) _loadData();
      }
    }
  }

  Widget _buildStationAdminsTab() {
    return Column(
      children: [
        // Action Bar with Create Button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Station Admins (${_stationAdmins.length})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                  ),
                  const Text(
                    'Super Admin exclusive: create & assign stations',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showCreateAdminDialog,
                icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                label: const Text(
                  'Create Admin',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.purple,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppTheme.border),
        Expanded(
          child: _stationAdmins.isEmpty
              ? const Center(child: Text('No Station Admins registered.', style: TextStyle(color: AppTheme.textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _stationAdmins.length,
                  itemBuilder: (context, i) {
                    final a = _stationAdmins[i];
                    final adminId = a['_id'] ?? a['id'] ?? '';
                    final name = a['name'] ?? 'Station Admin';
                    final email = a['email'] ?? '';
                    final phone = a['phone'] ?? '+91 9876543210';
                    final stationMap = a['assignedStation'] is Map ? a['assignedStation'] : null;
                    final stName = stationMap != null ? stationMap['stationName'] ?? 'Assigned Station' : 'Assigned Station';
                    final stAddress = stationMap != null ? stationMap['address'] ?? '' : '';
                    final availSlots = stationMap != null ? stationMap['availableSlots'] ?? 0 : 0;
                    final totalSlots = stationMap != null ? stationMap['totalSlots'] ?? 0 : 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.glassCardDecoration(),
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
                                    Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                                    const SizedBox(height: 2),
                                    Text('$email · $phone', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.purple.withOpacity(0.18),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppTheme.purple),
                                    ),
                                    child: Text(
                                      'ADMIN #${i + 1}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.purple),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                    onPressed: () => _deleteStationAdmin(adminId, name),
                                    tooltip: 'Delete Station Admin',
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(height: 20, color: AppTheme.border),
                          Row(
                            children: [
                              const Icon(Icons.ev_station_rounded, size: 20, color: AppTheme.neonGreen),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(stName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.neonGreen)),
                                    if (stAddress.isNotEmpty)
                                      Text(stAddress, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                  ],
                                ),
                              ),
                              Text(
                                '$availSlots / $totalSlots slots free',
                                style: const TextStyle(fontSize: 12, color: AppTheme.neonCyan, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 3: Network & ML Grid Forecast
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildNetworkMlTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Grid Stress & Load Forecast', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.glassCardDecoration(),
            child: Column(
              children: [
                _buildMetricRow('Network Utilization', '${_overviewMetrics?['networkUtilization'] ?? 35}%'),
                const Divider(height: 16, color: AppTheme.border),
                _buildMetricRow('Total Energy Dispensed', '${_overviewMetrics?['totalEnergyDispensed'] ?? 245.5} kWh'),
                const Divider(height: 16, color: AppTheme.border),
                _buildMetricRow('Grid Load Status', 'OPTIMAL - STABLE', color: AppTheme.neonGreen),
              ],
            ),
          ),
          const SizedBox(height: 18),

          const Text('Hourly Grid Demand Forecast', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.glassCardDecoration(),
            child: Column(
              children: _loadForecast.take(8).map((f) {
                final hour = f['hour'] ?? 12;
                final load = (f['predictedLoad'] as num?)?.toDouble() ?? 50.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$hour:00', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (load / 150.0).clamp(0.0, 1.0),
                              backgroundColor: AppTheme.border,
                              color: load > 100 ? Colors.redAccent : AppTheme.neonGreen,
                              minHeight: 6,
                            ),
                          ),
                        ),
                      ),
                      Text('${load.toStringAsFixed(1)} kW', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),

          const Text('Station-by-Station Grid Load Breakdown', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
          const SizedBox(height: 8),
          Column(
            children: _stations.take(6).map((st) {
              final activeCount = _allBookings.where((b) {
                final stId = b['station'] is Map ? b['station']['_id'] ?? b['station']['id'] : b['station']?.toString();
                return stId == st.id && (b['bookingStatus'] == 'Confirmed' || b['bookingStatus'] == 'Paid');
              }).length;
              final powerDraw = activeCount * st.chargerPower;
              final maxPower = st.totalSlots * st.chargerPower;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: AppTheme.glassCardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            st.stationName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textMain),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text('${st.availableSlots}/${st.totalSlots} slots free', style: const TextStyle(fontSize: 11, color: AppTheme.neonCyan)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: maxPower > 0 ? (powerDraw / maxPower).clamp(0.0, 1.0) : 0.0,
                              backgroundColor: AppTheme.border,
                              color: powerDraw > (maxPower * 0.75) ? Colors.redAccent : AppTheme.neonGreen,
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${powerDraw.toInt()} / ${maxPower.toInt()} kW',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 4: Users (Task 1)
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildUsersTab() {
    // Derive unique users from bookings
    final Map<String, Map<String, dynamic>> userMap = {};
    for (final b in _allBookings) {
      if (b['user'] is! Map) continue;
      final u = b['user'] as Map;
      final uid = u['_id']?.toString() ?? u['id']?.toString() ?? '';
      if (uid.isEmpty) continue;
      final cost = (b['estimatedCost'] as num?)?.toDouble() ?? 0.0;
      if (userMap.containsKey(uid)) {
        userMap[uid]!['bookings'] = (userMap[uid]!['bookings'] as int) + 1;
        userMap[uid]!['spend'] = (userMap[uid]!['spend'] as double) + cost;
      } else {
        userMap[uid] = {
          'name': u['name'] ?? 'Unknown User',
          'email': u['email'] ?? '',
          'bookings': 1,
          'spend': cost,
        };
      }
    }
    final users = userMap.values.toList()
      ..sort((a, b) => (b['bookings'] as int).compareTo(a['bookings'] as int));

    final totalUsers = _overviewMetrics?['totalUsers'] ?? users.length;
    final totalRevenue = (_overviewMetrics?['totalRevenue'] as num?)?.toDouble() ??
        users.fold<double>(0, (s, u) => s + (u['spend'] as double));

    return Column(
      children: [
        // Header summary card
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.glassCardDecoration(glow: true),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Platform Users', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      const SizedBox(height: 4),
                      Text(
                        '$totalUsers',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.neonCyan),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${users.length} users with bookings',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(width: 1, height: 60, color: AppTheme.border),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Revenue', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      const SizedBox(height: 4),
                      Text(
                        '₹${totalRevenue.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.neonGreen),
                      ),
                      const SizedBox(height: 4),
                      const Text('from all bookings', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Users list header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Row(
            children: [
              const Icon(Icons.people_outline_rounded, size: 15, color: AppTheme.textMuted),
              const SizedBox(width: 6),
              Text(
                users.isEmpty ? 'No booking data to derive users from' : 'Users derived from bookings (sorted by activity)',
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: AppTheme.border),

        // User list
        Expanded(
          child: users.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_outline_rounded, size: 48, color: AppTheme.textDim),
                      const SizedBox(height: 12),
                      const Text('No booking data available', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                      const SizedBox(height: 6),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: const Text(
                          'Full user list requires /api/auth/users endpoint',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: AppTheme.textDim),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: users.length,
                  itemBuilder: (context, i) {
                    final u = users[i];
                    final name = u['name'] as String;
                    final email = u['email'] as String;
                    final bookings = u['bookings'] as int;
                    final spend = u['spend'] as double;
                    final initials = name.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: AppTheme.glassCardDecoration(),
                      child: Row(
                        children: [
                          // Avatar
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: AppTheme.purple.withOpacity(0.2),
                            child: Text(
                              initials.isEmpty ? '?' : initials,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.purple),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Name + email
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                                if (email.isNotEmpty)
                                  Text(email, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                              ],
                            ),
                          ),
                          // Stats
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.receipt_rounded, size: 12, color: AppTheme.neonCyan),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$bookings ${bookings == 1 ? 'booking' : 'bookings'}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.neonCyan),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${spend.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.neonGreen),
                              ),
                            ],
                          ),
                          // Rank badge
                          const SizedBox(width: 8),
                          if (i < 3)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: [AppTheme.neonGreen, AppTheme.neonCyan, AppTheme.purple][i].withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: [AppTheme.neonGreen, AppTheme.neonCyan, AppTheme.purple][i].withOpacity(0.5)),
                              ),
                              child: Text(
                                ['#1', '#2', '#3'][i],
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: [AppTheme.neonGreen, AppTheme.neonCyan, AppTheme.purple][i],
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Shared helpers
  // ════════════════════════════════════════════════════════════════════════════
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

  Widget _buildMetricRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color ?? AppTheme.purple, fontSize: 14)),
      ],
    );
  }
}
