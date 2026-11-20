import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/station_model.dart';
import '../../models/slot_model.dart';
import '../../core/services/station_service.dart';
import '../../core/theme/app_theme.dart';
import '../booking/book_slot_screen.dart';

class StationDetailScreen extends StatefulWidget {
  final StationModel station;

  const StationDetailScreen({super.key, required this.station});

  @override
  State<StationDetailScreen> createState() => _StationDetailScreenState();
}

class _StationDetailScreenState extends State<StationDetailScreen> {
  final StationService _stationService = StationService();
  late StationModel _currentStation;
  DateTime _selectedDate = DateTime.now();
  List<SlotModel> _slots = [];
  bool _isLoadingSlots = true;
  SlotModel? _selectedSlot;
  Timer? _iotPollingTimer;

  @override
  void initState() {
    super.initState();
    _currentStation = widget.station;
    _fetchSlots();

    if (_currentStation.isIotHub) {
      _pollIotStatus();
      _iotPollingTimer = Timer.periodic(const Duration(milliseconds: 1500), (
        _,
      ) {
        _pollIotStatus();
      });
    }
  }

  @override
  void dispose() {
    _iotPollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _pollIotStatus() async {
    final updated = await _stationService.getIotHubStatus();
    if (updated != null && mounted) {
      setState(() {
        _currentStation = updated;
      });
    }
  }

  Future<void> _fetchSlots() async {
    setState(() => _isLoadingSlots = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final slots = await _stationService.getStationSlots(
      stationId: widget.station.id,
      dateStr: dateStr,
    );
    if (mounted) {
      setState(() {
        _slots = slots;
        _isLoadingSlots = false;
        _selectedSlot = null;
      });
    }
  }

  void _onDatePicked(DateTime date) {
    setState(() => _selectedDate = date);
    _fetchSlots();
  }

  Future<void> _simulateBayAction(int bay, String status) async {
    await _stationService.updateIotBay(bay: bay, status: status);
    _pollIotStatus();
  }

  @override
  Widget build(BuildContext context) {
    final s = _currentStation;
    final isFast = s.chargerPower >= 50;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Text(
                s.stationName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (s.isIotHub)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (s.isIotActive ? AppTheme.neonGreen : Colors.redAccent).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: s.isIotActive ? AppTheme.neonGreen : Colors.redAccent),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: s.isIotActive ? AppTheme.neonGreen : Colors.redAccent),
                    const SizedBox(width: 4),
                    Text(
                      s.isIotActive ? 'ESP32 LIVE' : 'NOT AVAILABLE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: s.isIotActive ? AppTheme.neonGreen : Colors.redAccent,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            border: const Border(
              top: BorderSide(color: AppTheme.border, width: 1.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rate: ₹${s.pricePerKwh.toStringAsFixed(1)} / kWh',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.neonCyan,
                      ),
                    ),
                    Text(
                      _selectedSlot != null
                          ? 'Slot: ${_selectedSlot!.slotTime}'
                          : (s.isIotHub
                                ? '${s.availableSlots}/2 Bays Free'
                                : 'Select a time slot'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textMain,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: _selectedSlot != null && _selectedSlot!.isAvailable
                      ? AppTheme.primaryGradient
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _selectedSlot != null && _selectedSlot!.isAvailable
                      ? [
                          BoxShadow(
                            color: AppTheme.neonGreen.withOpacity(0.3),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
                child: ElevatedButton(
                  onPressed:
                      _selectedSlot == null || !_selectedSlot!.isAvailable
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BookSlotScreen(
                                station: s,
                                selectedSlot: _selectedSlot!,
                                slotDate: DateFormat('yyyy-MM-dd')
                                    .format(_selectedDate),
                              ),
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    disabledBackgroundColor: AppTheme.bgCardHover,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                  ),
                  child: Text(
                    'Proceed to Book',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _selectedSlot != null && _selectedSlot!.isAvailable
                          ? const Color(0xFF0A0E17)
                          : AppTheme.textDim,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Station Header Glass Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: AppTheme.glassCardDecoration(glow: isFast),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isFast
                              ? AppTheme.neonCyan.withOpacity(0.15)
                              : AppTheme.neonGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isFast
                                ? AppTheme.neonCyan
                                : AppTheme.neonGreen,
                          ),
                        ),
                        child: Icon(
                          isFast
                              ? Icons.bolt_rounded
                              : Icons.electric_car_rounded,
                          size: 28,
                          color: isFast
                              ? AppTheme.neonCyan
                              : AppTheme.neonGreen,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.stationName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textMain,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${s.address}, ${s.city}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: AppTheme.border),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStat(
                        'Power',
                        '${s.chargerPower} kW',
                        AppTheme.neonGreen,
                      ),
                      _buildStat('Type', s.chargerType, AppTheme.neonCyan),
                      _buildStat(
                        'Available',
                        '${s.availableSlots}/${s.totalSlots}',
                        AppTheme.purple,
                      ),
                      _buildStat(
                        'Est. Wait',
                        '${s.waitMinutes}m',
                        AppTheme.electricBlue,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // If this is the IoT Hardware Hub, show the 2-Bay Hardware Visualizer
            if (s.isIotHub) ...[
              _buildIotBayVisualizer(),
              const SizedBox(height: 24),
            ],

            // Select Date Row
            const Text(
              'Select Charging Date',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textMain,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 72,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 7,
                itemBuilder: (context, i) {
                  final day = DateTime.now().add(Duration(days: i));
                  final isSelected =
                      DateFormat('yyyy-MM-dd').format(day) ==
                      DateFormat('yyyy-MM-dd').format(_selectedDate);

                  return GestureDetector(
                    onTap: () => _onDatePicked(day),
                    child: Container(
                      width: 64,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        gradient: isSelected ? AppTheme.primaryGradient : null,
                        color: isSelected ? null : AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.neonGreen
                              : AppTheme.border,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppTheme.neonGreen.withOpacity(0.3),
                                  blurRadius: 12,
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat('EEE').format(day),
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected
                                  ? const Color(0xFF0A0E17)
                                  : AppTheme.textMuted,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('d').format(day),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? const Color(0xFF0A0E17)
                                  : AppTheme.textMain,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Time Slots Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Available Time Slots',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMain,
                  ),
                ),
                Text(
                  DateFormat('EEE, MMM d').format(_selectedDate),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.neonCyan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _isLoadingSlots
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(
                        color: AppTheme.neonGreen,
                      ),
                    ),
                  )
                : _slots.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    decoration: AppTheme.glassCardDecoration(),
                    child: const Text(
                      'No slots found for this date. (Slots are generated by the seed script)',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  )
                : Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _slots.map((slot) {
                      final isSelected = _selectedSlot?.id == slot.id;
                      final isAvail = slot.isAvailable;

                      return ChoiceChip(
                        label: Text(slot.slotTime),
                        selected: isSelected,
                        onSelected: isAvail
                            ? (val) {
                                setState(() {
                                  _selectedSlot = val ? slot : null;
                                });
                              }
                            : null,
                        selectedColor: AppTheme.neonGreen,
                        backgroundColor: isAvail
                            ? AppTheme.bgCard
                            : AppTheme.bgCardHover.withOpacity(0.4),
                        side: BorderSide(
                          color: isSelected
                              ? AppTheme.neonGreen
                              : (isAvail
                                    ? AppTheme.border
                                    : Colors.transparent),
                        ),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? const Color(0xFF0A0E17)
                              : isAvail
                              ? AppTheme.textMain
                              : AppTheme.textDim,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildIotBayVisualizer() {
    final bool isActive = _currentStation.isIotActive;
    final bays = _currentStation.bays.isNotEmpty
        ? _currentStation.bays
        : [
            BayModel(bayNumber: 1, status: isActive ? 'Available' : 'Offline', lastUpdated: DateTime.now()),
            BayModel(bayNumber: 2, status: isActive ? 'Available' : 'Offline', lastUpdated: DateTime.now()),
          ];

    final b1 = bays.firstWhere((b) => b.bayNumber == 1, orElse: () => bays[0]);
    final b2 = bays.firstWhere(
      (b) => b.bayNumber == 2,
      orElse: () => bays.length > 1 ? bays[1] : bays[0],
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCardDecoration(glow: isActive),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isActive ? Icons.sensors_rounded : Icons.sensors_off_rounded,
                    color: isActive ? AppTheme.neonCyan : Colors.redAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'IoT Dual-Bay Live Status',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMain,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isActive ? AppTheme.neonGreen : Colors.redAccent).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isActive ? AppTheme.neonGreen : Colors.redAccent),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 7, color: isActive ? AppTheme.neonGreen : Colors.redAccent),
                    const SizedBox(width: 4),
                    Text(
                      isActive ? '${_currentStation.availableSlots}/2 Available' : 'Not Available',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isActive ? AppTheme.neonGreen : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Connectivity status banner
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isActive ? AppTheme.neonGreen.withOpacity(0.08) : Colors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive ? AppTheme.neonGreen.withOpacity(0.3) : Colors.redAccent.withOpacity(0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isActive ? Icons.wifi_tethering_rounded : Icons.wifi_off_rounded,
                  size: 18,
                  color: isActive ? AppTheme.neonGreen : Colors.redAccent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isActive
                        ? '🟢 IoT Status: Active (Live ESP32 Synced via Hotspot)'
                        : '⚠️ IoT Status: Not Available (ESP32 Offline / Inactive > 5 mins)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isActive ? AppTheme.neonGreen : Colors.redAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Two Bays Side by Side
          Row(
            children: [
              Expanded(child: _buildBayCard(b1, isActive)),
              const SizedBox(width: 12),
              Expanded(child: _buildBayCard(b2, isActive)),
            ],
          ),
          const SizedBox(height: 16),

          // Quick Demo Control simulation buttons
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.bgDark,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.touch_app_outlined,
                      size: 14,
                      color: AppTheme.neonCyan,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'ESP32 Test Simulation Panel:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildTestButton(
                      'B1: Parked',
                      () => _simulateBayAction(1, 'Parked'),
                      Colors.orange,
                    ),
                    _buildTestButton(
                      'B1: Charging',
                      () => _simulateBayAction(1, 'Charging'),
                      AppTheme.neonCyan,
                    ),
                    _buildTestButton(
                      'B2: Parked',
                      () => _simulateBayAction(2, 'Parked'),
                      Colors.orange,
                    ),
                    _buildTestButton(
                      'B2: Charging',
                      () => _simulateBayAction(2, 'Charging'),
                      AppTheme.neonCyan,
                    ),
                    _buildTestButton('Reset (Active)', () async {
                      await _stationService.resetIotBays();
                      _pollIotStatus();
                    }, AppTheme.neonGreen),
                    _buildTestButton('Simulate Offline', () async {
                      await _stationService.disconnectIot();
                      _pollIotStatus();
                    }, Colors.redAccent),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBayCard(BayModel bay, bool isHubActive) {
    Color statusColor;
    String statusTitle;
    String statusDesc;
    IconData statusIcon;

    if (!isHubActive || bay.isOffline) {
      statusColor = AppTheme.textDim;
      statusTitle = 'NOT AVAILABLE';
      statusDesc = 'ESP32 Offline (No link)';
      statusIcon = Icons.sensors_off_rounded;
    } else if (bay.isCharging) {
      statusColor = AppTheme.neonCyan;
      statusTitle = 'CHARGING';
      statusDesc = 'Button pressed (50 kW)';
      statusIcon = Icons.offline_bolt_rounded;
    } else if (bay.isParked) {
      statusColor = Colors.orange;
      statusTitle = 'PARKED';
      statusDesc = 'IR: Vehicle detected';
      statusIcon = Icons.directions_car_rounded;
    } else {
      statusColor = AppTheme.neonGreen;
      statusTitle = 'AVAILABLE';
      statusDesc = 'IR: Beam clear (Empty)';
      statusIcon = Icons.check_circle_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor, width: 1.5),
        boxShadow: isHubActive
            ? [
                BoxShadow(
                  color: statusColor.withOpacity(0.2),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'BAY #${bay.bayNumber}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppTheme.textMain,
                ),
              ),
              Icon(statusIcon, color: statusColor, size: 20),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: statusColor.withOpacity(0.5)),
            ),
            child: Text(
              statusTitle,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: statusColor,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            statusDesc,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton(String label, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.6)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
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
          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
      ],
    );
  }
}
