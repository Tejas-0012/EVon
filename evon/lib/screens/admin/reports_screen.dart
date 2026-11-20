import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/analytics_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();

  // Report type selection
  int _selectedReportType = 0; // 0=Bookings,1=Revenue,2=Stations,3=Energy
  static const List<String> _reportTypes = ['Bookings', 'Revenue', 'Stations', 'Energy'];

  // Date range filter
  int _selectedRange = 7; // days

  // Metrics
  Map<String, dynamic>? _overviewMetrics;
  bool _isLoading = true;

  // Mock monthly data: Oct–Apr (7 months)
  static const List<double> _mockMonthlyBookings = [2, 1, 3, 4, 2, 5, 3];
  static const List<String> _mockMonths = ['Oct', 'Nov', 'Dec', 'Jan', 'Feb', 'Mar', 'Apr'];

  // Mock station table data
  static const List<Map<String, dynamic>> _mockStations = [
    {'name': 'EVon Koramangala', 'bookings': 48, 'energy': 540.2, 'revenue': 6482.0, 'util': 78},
    {'name': 'EVon Whitefield',  'bookings': 36, 'energy': 405.8, 'revenue': 4869.6, 'util': 62},
    {'name': 'EVon MG Road',     'bookings': 55, 'energy': 621.4, 'revenue': 7456.8, 'util': 85},
    {'name': 'EVon Jayanagar',   'bookings': 29, 'energy': 318.6, 'revenue': 3823.2, 'util': 52},
    {'name': 'EVon Hebbal',      'bookings': 41, 'energy': 462.5, 'revenue': 5550.0, 'util': 71},
  ];

  @override
  void initState() {
    super.initState();
    _loadOverview();
  }

  Future<void> _loadOverview() async {
    setState(() => _isLoading = true);
    final metrics = await _analyticsService.getAdminOverview();
    if (mounted) {
      setState(() {
        _overviewMetrics = metrics;
        _isLoading = false;
      });
    }
  }

  // ─── Computed KPI values ───────────────────────────────────────────────────
  String get _kpiBookings =>
      _overviewMetrics?['totalBookings']?.toString() ?? '166';
  String get _kpiRevenue =>
      '₹${((_overviewMetrics?['totalRevenue'] as num?)?.toStringAsFixed(0)) ?? '28,181'}';
  String get _kpiStations =>
      _overviewMetrics?['totalStations']?.toString() ?? '5';
  String get _kpiUsers =>
      _overviewMetrics?['totalUsers']?.toString() ?? '214';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        title: const Text(
          'Reports',
          style: TextStyle(color: AppTheme.purple, fontWeight: FontWeight.bold),
        ),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Export CSV'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.neonGreen,
              side: const BorderSide(color: AppTheme.neonGreen, width: 1.2),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Export feature coming soon'),
                  backgroundColor: AppTheme.bgCard,
                ),
              );
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.purple,
        backgroundColor: AppTheme.bgCard,
        onRefresh: _loadOverview,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildReportTypeSelector(),
            const SizedBox(height: 14),
            _buildDateRangeRow(),
            const SizedBox(height: 20),
            _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(color: AppTheme.purple),
                    ),
                  )
                : _buildKPIRow(),
            const SizedBox(height: 20),
            _buildBarChartCard(),
            const SizedBox(height: 20),
            _buildStationTable(),
            const SizedBox(height: 24),
            _buildExportButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ─── Report Type Selector ──────────────────────────────────────────────────
  Widget _buildReportTypeSelector() {
    return Container(
      decoration: AppTheme.glassCardDecoration(),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Report Type',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(_reportTypes.length, (i) {
              final selected = _selectedReportType == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedReportType = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(right: i < _reportTypes.length - 1 ? 6 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: selected
                          ? const LinearGradient(
                              colors: [AppTheme.purple, AppTheme.neonCyan],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: selected ? null : AppTheme.bgDark,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? AppTheme.purple : AppTheme.border,
                        width: 1.2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _reportTypes[i],
                        style: TextStyle(
                          color: selected ? Colors.white : AppTheme.textMuted,
                          fontSize: 12.5,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ─── Date Range ────────────────────────────────────────────────────────────
  Widget _buildDateRangeRow() {
    final ranges = [7, 30, 90];
    final labels = ['Last 7 days', '30 days', '90 days'];
    return Row(
      children: List.generate(ranges.length, (i) {
        final selected = _selectedRange == ranges[i];
        return Padding(
          padding: EdgeInsets.only(right: i < ranges.length - 1 ? 8 : 0),
          child: FilterChip(
            label: Text(labels[i]),
            selected: selected,
            onSelected: (_) => setState(() => _selectedRange = ranges[i]),
            backgroundColor: AppTheme.bgCard,
            selectedColor: AppTheme.purple.withOpacity(0.25),
            checkmarkColor: AppTheme.purple,
            labelStyle: TextStyle(
              color: selected ? AppTheme.purple : AppTheme.textMuted,
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
            side: BorderSide(
              color: selected ? AppTheme.purple : AppTheme.border,
              width: 1.2,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        );
      }),
    );
  }

  // ─── KPI Row ──────────────────────────────────────────────────────────────
  Widget _buildKPIRow() {
    final kpis = [
      {'icon': Icons.calendar_today_rounded, 'label': 'Bookings', 'value': _kpiBookings, 'color': AppTheme.neonGreen},
      {'icon': Icons.currency_rupee_rounded, 'label': 'Revenue', 'value': _kpiRevenue, 'color': AppTheme.neonCyan},
      {'icon': Icons.ev_station_rounded,     'label': 'Stations', 'value': _kpiStations, 'color': AppTheme.purple},
      {'icon': Icons.people_rounded,         'label': 'Users',    'value': _kpiUsers,    'color': Colors.orange},
    ];
    return Row(
      children: kpis.map((k) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: k == kpis.last ? 0 : 8),
            decoration: AppTheme.glassCardDecoration(
              borderColor: (k['color'] as Color).withOpacity(0.3),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            child: Column(
              children: [
                Icon(k['icon'] as IconData, color: k['color'] as Color, size: 20),
                const SizedBox(height: 6),
                Text(
                  k['value'] as String,
                  style: TextStyle(
                    color: k['color'] as Color,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  k['label'] as String,
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 10.5),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Bar Chart ─────────────────────────────────────────────────────────────
  Widget _buildBarChartCard() {
    return Container(
      decoration: AppTheme.glassCardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: AppTheme.purple, size: 20),
              const SizedBox(width: 8),
              Text(
                '${_reportTypes[_selectedReportType]} — Monthly Overview',
                style: const TextStyle(
                  color: AppTheme.textMain,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Oct 2024 – Apr 2025',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 7,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppTheme.bgCard,
                    getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                      '${_mockMonths[group.x]}\n${rod.toY.toInt()}',
                      const TextStyle(color: AppTheme.neonGreen, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _mockMonths[value.toInt()],
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                        ),
                      ),
                      reservedSize: 26,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 2,
                      getTitlesWidget: (value, _) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                      ),
                      reservedSize: 20,
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 2,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppTheme.border,
                    strokeWidth: 1,
                  ),
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(7, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: _mockMonthlyBookings[i],
                        gradient: const LinearGradient(
                          colors: [AppTheme.purple, AppTheme.neonCyan],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        width: 22,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Station Table ─────────────────────────────────────────────────────────
  Widget _buildStationTable() {
    return Container(
      decoration: AppTheme.glassCardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.ev_station_rounded, color: AppTheme.neonCyan, size: 20),
              SizedBox(width: 8),
              Text(
                'Station Performance',
                style: TextStyle(color: AppTheme.textMain, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Header row
          _tableRow(
            const ['Station', 'Bkgs', 'kWh', 'Revenue', 'Util%'],
            isHeader: true,
          ),
          const Divider(color: AppTheme.border, height: 1),
          // Data rows
          ..._mockStations.map((s) {
            return _tableRow([
              s['name'] as String,
              s['bookings'].toString(),
              (s['energy'] as double).toStringAsFixed(1),
              '₹${(s['revenue'] as double).toStringAsFixed(0)}',
              '${s['util']}%',
            ]);
          }),
        ],
      ),
    );
  }

  Widget _tableRow(List<String> cells, {bool isHeader = false}) {
    final style = isHeader
        ? const TextStyle(color: AppTheme.textMuted, fontSize: 11.5, fontWeight: FontWeight.w600)
        : const TextStyle(color: AppTheme.textMain, fontSize: 12);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(cells[0], style: style, overflow: TextOverflow.ellipsis),
          ),
          Expanded(child: Text(cells[1], style: style, textAlign: TextAlign.center)),
          Expanded(child: Text(cells[2], style: style, textAlign: TextAlign.center)),
          Expanded(
            flex: 2,
            child: Text(
              cells[3],
              style: isHeader ? style : style.copyWith(color: AppTheme.neonGreen),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              cells[4],
              style: isHeader
                  ? style
                  : style.copyWith(
                      color: int.tryParse(cells[4].replaceAll('%', '')) != null &&
                              int.parse(cells[4].replaceAll('%', '')) > 70
                          ? Colors.orange
                          : AppTheme.neonCyan,
                    ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Export Button ─────────────────────────────────────────────────────────
  Widget _buildExportButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.download_rounded, size: 20),
        label: const Text('Export CSV', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.neonGreen,
          side: const BorderSide(color: AppTheme.neonGreen, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Export feature coming soon'),
              backgroundColor: AppTheme.bgCard,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }
}
