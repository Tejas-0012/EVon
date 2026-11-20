import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/services/analytics_service.dart';
import '../../core/theme/app_theme.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();
  Map<String, dynamic>? _metrics;
  List<Map<String, dynamic>> _forecastData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final metrics = await _analyticsService.getAdminOverview();
    final forecast = await _analyticsService.getLoadForecast();
    setState(() {
      _metrics = metrics;
      _forecastData = forecast;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('Analytics & Grid Forecasting', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.neonCyan),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.neonGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI Overview Cards
                  const Text('Platform Key Metrics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildKpiCard(
                          'Active Stations',
                          '${_metrics?['totalStations'] ?? 8}',
                          Icons.ev_station_rounded,
                          AppTheme.neonGreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildKpiCard(
                          'Total Bookings',
                          '${_metrics?['totalBookings'] ?? 15}',
                          Icons.event_available_rounded,
                          AppTheme.neonCyan,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildKpiCard(
                          'Network Load',
                          '${_metrics?['networkUtilization'] ?? 35}%',
                          Icons.speed_rounded,
                          AppTheme.purple,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildKpiCard(
                          'Total Revenue',
                          '₹${(_metrics?['totalRevenue'] as num?)?.toStringAsFixed(0) ?? '2,400'}',
                          Icons.currency_rupee_rounded,
                          AppTheme.electricBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 24-Hour Load Forecast Chart
                  const Text(
                    '24-Hour LSTM Grid Load Forecast',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Predicted aggregated charging load (kW) across the Bangalore grid',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.only(top: 24, right: 24, left: 12, bottom: 16),
                    decoration: AppTheme.glassCardDecoration(glow: true),
                    child: SizedBox(
                      height: 220,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (value) => const FlLine(
                              color: AppTheme.border,
                              strokeWidth: 1,
                            ),
                          ),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 4,
                                getTitlesWidget: (val, meta) => Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    '${val.toInt()}h',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                  ),
                                ),
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 42,
                                getTitlesWidget: (val, meta) => Text(
                                  '${val.toInt()}kW',
                                  style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                ),
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: _generateSpots(),
                              isCurved: true,
                              color: AppTheme.neonGreen,
                              barWidth: 3,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.neonGreen.withOpacity(0.35),
                                    AppTheme.neonGreen.withOpacity(0.0),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ML Engine Status Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: AppTheme.glassCardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.purple.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.purple),
                              ),
                              child: const Icon(Icons.memory_rounded, color: AppTheme.purple, size: 24),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'EVon ML Microservice Bridge',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textMain, fontSize: 14),
                                ),
                                Text(
                                  'FastAPI Python :8000 ↔ Node.js :5000',
                                  style: TextStyle(fontSize: 12, color: AppTheme.neonCyan),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 20, color: AppTheme.border),
                        const Text(
                          '• Random Forest Regressor: Predicts hourly slot demand and congestion probability.\n'
                          '• Keras LSTM Neural Network: 24-hour rolling sequence grid load forecaster.\n'
                          '• Resilient Heuristics: Zero-downtime mathematical fallbacks when ML service restarts.',
                          style: TextStyle(fontSize: 12, height: 1.6, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  List<FlSpot> _generateSpots() {
    if (_forecastData.isNotEmpty) {
      return _forecastData.asMap().entries.map((e) {
        final double x = (e.value['hour'] as num?)?.toDouble() ?? e.key.toDouble();
        final double y = (e.value['predictedLoadKw'] as num?)?.toDouble() ?? 50.0;
        return FlSpot(x, y);
      }).toList();
    }

    return const [
      FlSpot(0, 25), FlSpot(2, 20), FlSpot(4, 15), FlSpot(6, 30),
      FlSpot(8, 75), FlSpot(10, 110), FlSpot(12, 125), FlSpot(14, 115),
      FlSpot(16, 95), FlSpot(18, 140), FlSpot(20, 130), FlSpot(22, 65), FlSpot(24, 30),
    ];
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}
