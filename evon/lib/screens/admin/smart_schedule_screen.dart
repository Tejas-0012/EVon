import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/analytics_service.dart';

class SmartScheduleScreen extends StatefulWidget {
  const SmartScheduleScreen({super.key});

  @override
  State<SmartScheduleScreen> createState() => _SmartScheduleScreenState();
}

class _SmartScheduleScreenState extends State<SmartScheduleScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();

  static const List<double> _fallbackDemand = [
    0.1, 0.1, 0.08, 0.08, 0.15, 0.3,
    0.6, 0.85, 0.9, 0.8, 0.65, 0.5,
    0.45, 0.6, 0.75, 0.8, 0.9, 0.95,
    1.0, 0.9, 0.75, 0.55, 0.3, 0.15,
  ];

  static const Set<int> _recommendedHours = {6, 7, 8, 11, 12, 13, 22, 23};

  List<double> _demandData = List.from(_fallbackDemand);
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadForecast();
  }

  Future<void> _loadForecast() async {
    try {
      final forecast = await _analyticsService.getLoadForecast();
      if (forecast.isNotEmpty && forecast.length >= 24) {
        final parsed = List<double>.generate(
          24,
          (i) => (forecast[i]['demand'] as num?)?.toDouble() ?? _fallbackDemand[i],
        );
        if (mounted) setState(() => _demandData = parsed);
      }
    } catch (_) {
      // fall back to hardcoded
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _demandColor(double demand) {
    if (demand < 0.4) return AppTheme.neonGreen;
    if (demand <= 0.7) return Colors.orange;
    return Colors.redAccent;
  }

  String _hourLabel(int hour) =>
      '${hour.toString().padLeft(2, '0')}:00';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        title: const Text(
          'Smart Schedule',
          style: TextStyle(color: AppTheme.neonGreen, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.neonGreen,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.neonGreen),
            tooltip: 'Refresh forecast',
            onPressed: () {
              setState(() => _isLoading = true);
              _loadForecast();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.neonGreen,
        backgroundColor: AppTheme.bgCard,
        onRefresh: _loadForecast,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 12),
            _buildPeakBanner(),
            const SizedBox(height: 20),
            _buildSlotsGridHeader(),
            const SizedBox(height: 12),
            _buildSlotsGrid(),
            const SizedBox(height: 20),
            _buildSummaryCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      decoration: AppTheme.glassCardDecoration(glow: true),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.neonGreen, AppTheme.neonCyan],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.neonGreen.withOpacity(0.35),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(Icons.schedule_rounded, color: AppTheme.bgDark, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Smart Off-Peak Scheduler',
                  style: TextStyle(
                    color: AppTheme.textMain,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'AI-powered slot recommendations to reduce grid congestion',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeakBanner() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withOpacity(0.5), width: 1.2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 22),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Peak Window: 17:00–21:00',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Avoid charging during this period to save costs & reduce grid load',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlotsGridHeader() {
    return Row(
      children: [
        const Icon(Icons.bolt_rounded, color: AppTheme.neonCyan, size: 18),
        const SizedBox(width: 8),
        const Text(
          '24-Hour Demand Forecast',
          style: TextStyle(
            color: AppTheme.textMain,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        _legendChip(AppTheme.neonGreen, 'Low'),
        const SizedBox(width: 6),
        _legendChip(Colors.orange, 'Mid'),
        const SizedBox(width: 6),
        _legendChip(Colors.redAccent, 'High'),
      ],
    );
  }

  Widget _legendChip(Color color, String label) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
      ],
    );
  }

  Widget _buildSlotsGrid() {
    // Use a GridView for the 24 cards
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.6,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: 24,
      itemBuilder: (context, hour) {
        final demand = _demandData[hour];
        final isRecommended = _recommendedHours.contains(hour);
        final color = _demandColor(demand);
        return _buildSlotCard(hour, demand, isRecommended, color);
      },
    );
  }

  Widget _buildSlotCard(int hour, double demand, bool isRecommended, Color demandColor) {
    return Container(
      decoration: BoxDecoration(
        color: isRecommended
            ? AppTheme.neonGreen.withOpacity(0.07)
            : AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRecommended
              ? AppTheme.neonGreen.withOpacity(0.45)
              : AppTheme.border,
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _hourLabel(hour),
                style: TextStyle(
                  color: isRecommended ? AppTheme.neonGreen : AppTheme.textMain,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isRecommended)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.neonGreen.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.neonGreen.withOpacity(0.5)),
                  ),
                  child: const Text(
                    'REC',
                    style: TextStyle(
                      color: AppTheme.neonGreen,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: demand,
              backgroundColor: AppTheme.textDim.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(demandColor),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${(demand * 100).toStringAsFixed(0)}% demand',
            style: TextStyle(color: demandColor, fontSize: 10, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      decoration: AppTheme.glassCardDecoration(
        borderColor: AppTheme.neonGreen.withOpacity(0.4),
        glow: true,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.tips_and_updates_rounded, color: AppTheme.neonGreen, size: 20),
              SizedBox(width: 10),
              Text(
                'Optimal Charging Windows',
                style: TextStyle(
                  color: AppTheme.neonGreen,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _windowRow(Icons.wb_sunny_outlined, '6:00 AM – 8:00 AM', 'Early morning — lowest overnight demand'),
          const SizedBox(height: 10),
          _windowRow(Icons.wb_cloudy_outlined, '11:00 AM – 1:00 PM', 'Mid-day lull between commutes'),
          const SizedBox(height: 10),
          _windowRow(Icons.nights_stay_outlined, '10:00 PM – 12:00 AM', 'Post-peak evening cool-down'),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.neonGreen.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.neonGreen.withOpacity(0.25)),
            ),
            child: const Text(
              '💡 Best charging windows: 6–8 AM, 11 AM–1 PM, 10 PM–12 AM',
              style: TextStyle(
                color: AppTheme.textMain,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _windowRow(IconData icon, String time, String desc) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.neonCyan, size: 18),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              time,
              style: const TextStyle(color: AppTheme.textMain, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            Text(
              desc,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
            ),
          ],
        ),
      ],
    );
  }
}
