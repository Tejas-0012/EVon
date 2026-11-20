import 'package:flutter/material.dart';
import '../../models/booking_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/booking_service.dart';

class BookingDetailScreen extends StatefulWidget {
  final BookingModel booking;

  const BookingDetailScreen({super.key, required this.booking});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  final BookingService _bookingService = BookingService();
  late BookingModel _booking;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
  }

  Future<void> _cancelBooking() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: const Text(
          'Cancel Booking?',
          style: TextStyle(color: AppTheme.textMain),
        ),
        content: const Text(
          'Are you sure you want to cancel this charging slot reservation?',
          style: TextStyle(color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Cancel Booking', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isProcessing = true);
      final res = await _bookingService.cancelBooking(_booking.id);
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: res.success ? AppTheme.neonGreen : Colors.red,
          ),
        );
        if (res.success) Navigator.pop(context, true);
      }
    }
  }

  Future<void> _payBooking() async {
    setState(() => _isProcessing = true);
    final res = await _bookingService.payBooking(
      bookingId: _booking.id,
      paymentMethod: 'UPI',
    );
    if (mounted) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.success ? AppTheme.neonGreen : Colors.red,
        ),
      );
      if (res.success) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _booking;
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('Booking Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: AppTheme.neonCyan),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share feature coming soon!')),
              );
            },
          ),
        ],
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator(color: AppTheme.neonGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStatusHeroCard(b),
                  const SizedBox(height: 14),
                  _buildStationInfoCard(b),
                  const SizedBox(height: 14),
                  _buildSessionDetailsGrid(b),
                  const SizedBox(height: 14),
                  _buildEnergyCostCard(b),
                  const SizedBox(height: 14),
                  _buildPaymentReceiptCard(b),
                  const SizedBox(height: 20),
                  _buildActionButtons(b),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  // ── 1. Status Hero Card ──────────────────────────────────────────────────
  Widget _buildStatusHeroCard(BookingModel b) {
    final IconData heroIcon;
    final Color iconColor;
    if (b.isCompleted) {
      heroIcon = Icons.check_circle_rounded;
      iconColor = AppTheme.neonCyan;
    } else if (b.isCancelled) {
      heroIcon = Icons.cancel_rounded;
      iconColor = Colors.redAccent;
    } else {
      heroIcon = Icons.hourglass_top_rounded;
      iconColor = Colors.orangeAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: AppTheme.glassCardDecoration(glow: b.isPaid),
      child: Column(
        children: [
          Icon(heroIcon, size: 72, color: iconColor),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildBadge(_statusLabel(b), _statusColor(b)),
              const SizedBox(width: 10),
              _buildBadge(
                b.isPaid ? 'Paid' : (b.paymentStatus),
                b.isPaid ? AppTheme.neonGreen : Colors.orangeAccent,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '#${b.id.substring(0, b.id.length >= 8 ? 8 : b.id.length).toUpperCase()}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textMain,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Booking ID',
            style: TextStyle(fontSize: 12, color: AppTheme.textDim),
          ),
        ],
      ),
    );
  }

  // ── 2. Station Info Card ─────────────────────────────────────────────────
  Widget _buildStationInfoCard(BookingModel b) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.glassCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.neonGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderGlow),
                ),
                child: const Icon(
                  Icons.ev_station_rounded,
                  color: AppTheme.neonGreen,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Charging Station',
                      style: TextStyle(fontSize: 11, color: AppTheme.textDim),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      b.stationName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textMain,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (b.stationAddress.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppTheme.border),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_rounded, size: 18, color: AppTheme.neonCyan),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    b.stationAddress,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── 3. Session Details Grid ───────────────────────────────────────────────
  Widget _buildSessionDetailsGrid(BookingModel b) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.glassCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Session Details',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textMain,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildDetailTile(Icons.calendar_today_rounded, 'Date', b.slotDate, AppTheme.neonCyan)),
              const SizedBox(width: 10),
              Expanded(child: _buildDetailTile(Icons.access_time_rounded, 'Time', b.slotTime, AppTheme.purple)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildDetailTile(
                  Icons.directions_car_rounded,
                  'Vehicle',
                  b.vehicleType,
                  AppTheme.electricBlue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDetailTile(
                  Icons.battery_charging_full_rounded,
                  'Battery',
                  '${b.currentSoc.toInt()}% → ${b.desiredSoc.toInt()}%',
                  AppTheme.neonGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTile(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textDim)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textMain),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── 4. Energy & Cost Breakdown Card ─────────────────────────────────────
  Widget _buildEnergyCostCard(BookingModel b) {
    const double costPerKwh = 12.0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.glassCardDecoration(glow: b.isPaid),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Energy & Cost Breakdown',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textMain,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 16),
          _buildCostRow(Icons.bolt_rounded, 'Energy Required', '${b.energyRequired.toStringAsFixed(2)} kWh', AppTheme.neonGreen),
          const SizedBox(height: 10),
          _buildCostRow(Icons.timer_rounded, 'Charging Duration', '${b.chargingDuration.toStringAsFixed(2)} hrs', AppTheme.neonCyan),
          const SizedBox(height: 10),
          _buildCostRow(Icons.attach_money_rounded, 'Cost per kWh', '₹${costPerKwh.toStringAsFixed(1)}', AppTheme.purple),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppTheme.border),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Cost',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textMain,
                ),
              ),
              Text(
                '₹${b.estimatedCost.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.neonGreen,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCostRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted))),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  // ── 5. Payment Receipt Card ──────────────────────────────────────────────
  Widget _buildPaymentReceiptCard(BookingModel b) {
    final created = b.createdAt;
    final dateStr =
        '${created.day.toString().padLeft(2, '0')}/${created.month.toString().padLeft(2, '0')}/${created.year}  ${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.glassCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Receipt',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textMain,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.payment_rounded, size: 18, color: AppTheme.electricBlue),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Payment Method', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.electricBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.electricBlue.withOpacity(0.4)),
                ),
                child: const Text(
                  'UPI',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.electricBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                b.isPaid ? Icons.verified_rounded : Icons.pending_rounded,
                size: 18,
                color: b.isPaid ? AppTheme.neonGreen : Colors.orangeAccent,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Payment Status', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
              ),
              _buildBadge(
                b.paymentStatus,
                b.isPaid ? AppTheme.neonGreen : Colors.orangeAccent,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.access_time_filled_rounded, size: 18, color: AppTheme.textDim),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Created At', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
              ),
              Text(
                dateStr,
                style: const TextStyle(fontSize: 12, color: AppTheme.textDim, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 6. Action Buttons ────────────────────────────────────────────────────
  Widget _buildActionButtons(BookingModel b) {
    final showCancel = b.canCancel;
    final showPay = !b.isPaid && !b.isCancelled && !b.isCompleted;

    if (!showCancel && !showPay) return const SizedBox.shrink();

    return Row(
      children: [
        if (showCancel) ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _cancelBooking,
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('Cancel Booking'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (showPay) const SizedBox(width: 10),
        ],
        if (showPay) ...[
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.neonGreen.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _payBooking,
                icon: const Icon(Icons.payment_rounded, size: 18),
                label: const Text('Pay Now (UPI)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: const Color(0xFF0A0E17),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  String _statusLabel(BookingModel b) {
    if (b.isCompleted) return 'Completed';
    if (b.isCancelled) {
      return b.paymentStatus.toLowerCase() == 'refunded' ? 'Cancelled (Refunded)' : 'Cancelled';
    }
    if (b.isPaid) return 'Paid & Confirmed';
    if (b.isConfirmed) return 'Confirmed';
    return b.status;
  }

  Color _statusColor(BookingModel b) {
    if (b.isCompleted) return AppTheme.neonCyan;
    if (b.isCancelled) return Colors.redAccent;
    if (b.isPaid || b.isConfirmed) return AppTheme.neonGreen;
    return Colors.orangeAccent;
  }
}
