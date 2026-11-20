import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/station_model.dart';
import '../../models/slot_model.dart';
import '../../models/quote_model.dart';
import '../../core/services/booking_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import 'payment_success_screen.dart';

class BookSlotScreen extends StatefulWidget {
  final StationModel station;
  final SlotModel selectedSlot;
  final String slotDate;

  const BookSlotScreen({
    super.key,
    required this.station,
    required this.selectedSlot,
    required this.slotDate,
  });

  @override
  State<BookSlotScreen> createState() => _BookSlotScreenState();
}

class _BookSlotScreenState extends State<BookSlotScreen> {
  final BookingService _bookingService = BookingService();

  double _batteryCapacity = 60.0;
  double _currentSoc = 20.0;
  double _desiredSoc = 80.0;
  String _vehicleType = 'Electric Car';

  QuoteModel? _quote;
  bool _isLoadingQuote = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.currentUser != null) {
      _batteryCapacity = auth.currentUser!.batteryCapacity;
      _vehicleType = auth.currentUser!.vehicleType;
    }
    _calculateQuote();
  }

  Future<void> _calculateQuote() async {
    setState(() => _isLoadingQuote = true);
    final quote = await _bookingService.getQuote(
      stationId: widget.station.id,
      batteryCapacity: _batteryCapacity,
      currentSoc: _currentSoc,
      desiredSoc: _desiredSoc,
      slotDate: widget.slotDate,
      slotTime: widget.selectedSlot.slotTime,
    );
    setState(() {
      _quote = quote;
      _isLoadingQuote = false;
    });
  }

  Future<void> _handleConfirmBooking() async {
    setState(() => _isSubmitting = true);

    final booking = await _bookingService.createBooking(
      stationId: widget.station.id,
      slotId: widget.selectedSlot.id,
      slotDate: widget.slotDate,
      slotTime: widget.selectedSlot.slotTime,
      vehicleType: _vehicleType,
      batteryCapacity: _batteryCapacity,
      currentSoc: _currentSoc,
      desiredSoc: _desiredSoc,
    );

    setState(() => _isSubmitting = false);

    if (booking != null && mounted) {
      _showSuccessDialog(booking.id, booking.estimatedCost);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Failed to book slot. It may have already been reserved.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccessDialog(String bookingId, double cost) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.borderGlow),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.neonGreen.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.neonGreen),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.neonGreen,
                size: 52,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Slot Reserved!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textMain,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your charging session at ${widget.station.stationName} is locked for ${widget.selectedSlot.slotTime}.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.bgDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Estimated Cost:',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                  Text(
                    '₹${cost.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppTheme.neonGreen,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textMuted,
                      side: const BorderSide(color: AppTheme.border),
                    ),
                    child: const Text('Pay Later'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _handlePayNow(bookingId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                      ),
                      child: const Text(
                        'Pay (UPI)',
                        style: TextStyle(
                          color: Color(0xFF0A0E17),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePayNow(String bookingId) async {
    final res = await _bookingService.payBooking(bookingId: bookingId, paymentMethod: 'UPI');
    if (mounted) {
      if (res.success) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentSuccessScreen(
              stationName: widget.station.stationName,
              slotDate: widget.slotDate,
              slotTime: widget.selectedSlot.slotTime,
              energyKwh: _quote?.energyRequired ?? 0.0,
              totalCost: _quote?.estimatedCost ?? 0.0,
              bookingId: bookingId,
            ),
          ),
          (r) => r.isFirst,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.station;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(title: const Text('Configure Charging Session')),
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
                    const Text(
                      'Total Estimated Cost',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    Text(
                      _quote != null
                          ? '₹${_quote!.estimatedCost.toStringAsFixed(2)}'
                          : 'Calculating...',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.neonGreen,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: _isSubmitting || _isLoadingQuote
                      ? null
                      : AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.neonGreen.withOpacity(0.3),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isSubmitting || _isLoadingQuote
                      ? null
                      : _handleConfirmBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    disabledBackgroundColor: AppTheme.bgCardHover,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Color(0xFF0A0E17),
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Confirm & Book',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A0E17),
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
            // Selected Slot summary
            Container(
              padding: const EdgeInsets.all(14),
              decoration: AppTheme.glassCardDecoration(glow: true),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.neonGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.neonGreen),
                    ),
                    child: const Icon(
                      Icons.calendar_today_rounded,
                      color: AppTheme.neonGreen,
                      size: 22,
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
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppTheme.textMain,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Date: ${widget.slotDate} · Time: ${widget.selectedSlot.slotTime}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.neonCyan,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Smart Booking Guidance matching book_slot.html #smartSchedulePanel
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.glassCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: AppTheme.neonCyan,
                            size: 18,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Smart Booking Guidance',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppTheme.neonCyan,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.neonGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.neonGreen),
                        ),
                        child: Text(
                          _quote?.demandLevel == 'High'
                              ? 'Peak hours'
                              : 'Off-peak',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _quote?.demandLevel == 'High'
                                ? Colors.redAccent
                                : AppTheme.neonGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildGuidanceTile(
                          'Predicted Demand',
                          _quote?.demandLevel ?? 'Moderate',
                          AppTheme.neonGreen,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildGuidanceTile(
                          'Estimated Wait',
                          '${s.waitMinutes} mins',
                          AppTheme.neonCyan,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildGuidanceTile(
                          'Congestion',
                          _quote?.congestion ?? 'Low',
                          AppTheme.purple,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Battery SoC Slider Section
            const Text(
              'Battery State of Charge (SoC)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textMain,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.glassCardDecoration(),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Current Battery Level:',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                      Text(
                        '${_currentSoc.toInt()}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _currentSoc,
                    min: 5,
                    max: 95,
                    divisions: 18,
                    activeColor: Colors.orange,
                    inactiveColor: AppTheme.bgDark,
                    onChanged: (val) {
                      setState(() {
                        _currentSoc = val;
                        if (_desiredSoc <= _currentSoc) {
                          _desiredSoc = (_currentSoc + 10).clamp(10, 100);
                        }
                      });
                      _calculateQuote();
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Desired Target Level:',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                      Text(
                        '${_desiredSoc.toInt()}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.neonGreen,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _desiredSoc,
                    min: 10,
                    max: 100,
                    divisions: 18,
                    activeColor: AppTheme.neonGreen,
                    inactiveColor: AppTheme.bgDark,
                    onChanged: (val) {
                      if (val > _currentSoc) {
                        setState(() => _desiredSoc = val);
                        _calculateQuote();
                      }
                    },
                  ),
                  const Divider(height: 20, color: AppTheme.border),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Battery Pack Size:',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                      Text(
                        '${_batteryCapacity.toInt()} kWh',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.neonCyan,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Dynamic Charging Calculation & Quote
            const Text(
              'Charging Session Quotation',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textMain,
              ),
            ),
            const SizedBox(height: 10),

            if (_isLoadingQuote)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: AppTheme.neonGreen),
                ),
              )
            else if (_quote != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.glassCardDecoration(glow: true),
                child: Column(
                  children: [
                    _buildQuoteRow(
                      icon: Icons.electric_bolt_rounded,
                      label: 'Energy to Transfer',
                      value: '${_quote!.energyRequired.toStringAsFixed(2)} kWh',
                      valueColor: AppTheme.neonGreen,
                    ),
                    const Divider(height: 20, color: AppTheme.border),
                    _buildQuoteRow(
                      icon: Icons.timer_outlined,
                      label: 'Estimated Charging Time',
                      value:
                          '${(_quote!.chargingDuration * 60).round()} mins (${_quote!.chargingDuration.toStringAsFixed(2)} hrs)',
                      valueColor: AppTheme.neonCyan,
                    ),
                    const Divider(height: 20, color: AppTheme.border),
                    _buildQuoteRow(
                      icon: Icons.auto_awesome_rounded,
                      label: 'ML Demand Forecast',
                      value: _quote!.demandLevel,
                      valueColor: _quote!.demandLevel == 'High'
                          ? Colors.redAccent
                          : AppTheme.neonGreen,
                    ),
                    const Divider(height: 20, color: AppTheme.border),
                    _buildQuoteRow(
                      icon: Icons.currency_rupee_rounded,
                      label: 'Estimated Total Cost',
                      value: '₹${_quote!.estimatedCost.toStringAsFixed(2)}',
                      valueColor: AppTheme.neonGreen,
                      isBold: true,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidanceTile(String title, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            val,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: valueColor ?? AppTheme.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: AppTheme.textMain),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? AppTheme.textMain,
          ),
        ),
      ],
    );
  }
}
