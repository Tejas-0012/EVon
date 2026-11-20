import 'package:flutter/material.dart';

import '../../models/booking_model.dart';
import '../../core/services/booking_service.dart';
import '../../core/theme/app_theme.dart';
import 'booking_detail_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final BookingService _bookingService = BookingService();
  List<BookingModel> _bookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    final list = await _bookingService.getMyBookings();
    setState(() {
      _bookings = list;
      _isLoading = false;
    });
  }

  Future<void> _cancelBooking(String id) async {
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
            child: const Text(
              'Keep',
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Cancel Booking',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await _bookingService.cancelBooking(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: res.success ? AppTheme.neonGreen : Colors.red,
          ),
        );
        _loadBookings();
      }
    }
  }

  Future<void> _payBooking(String id) async {
    final res = await _bookingService.payBooking(
      bookingId: id,
      paymentMethod: 'UPI',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.success ? AppTheme.neonGreen : Colors.red,
        ),
      );
      if (res.success) _loadBookings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text(
          'Booking History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.neonCyan),
            onPressed: _loadBookings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.neonGreen),
            )
          : _bookings.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.event_busy_rounded,
                    size: 64,
                    color: AppTheme.textDim,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No bookings yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMain,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Reserve a charging slot from the Stations tab.',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadBookings,
              color: AppTheme.neonGreen,
              backgroundColor: AppTheme.bgCard,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _bookings.length,
                itemBuilder: (context, i) {
                  final b = _bookings[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      final changed = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookingDetailScreen(booking: b),
                        ),
                      );
                      if (changed == true) _loadBookings();
                    },
                    child: Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: AppTheme.glassCardDecoration(glow: b.isPaid),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                b.stationName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textMain,
                                ),
                              ),
                            ),
                            _buildStatusBadge(b.status, b.paymentStatus),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_rounded,
                              size: 16,
                              color: AppTheme.neonCyan,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${b.slotDate} at ${b.slotTime}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.neonCyan,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20, color: AppTheme.border),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildInfoCol(
                              'Energy',
                              '${b.energyRequired.toStringAsFixed(1)} kWh',
                              AppTheme.neonGreen,
                            ),
                            _buildInfoCol(
                              'Battery SoC',
                              '${b.currentSoc.toInt()}% → ${b.desiredSoc.toInt()}%',
                              AppTheme.purple,
                            ),
                            _buildInfoCol(
                              'Amount',
                              '₹${b.estimatedCost.toStringAsFixed(2)}',
                              AppTheme.neonCyan,
                            ),
                          ],
                        ),
                        if (b.canCancel || (!b.isPaid && !b.isCompleted && !b.isCancelled)) ...[
                          const Divider(height: 20, color: AppTheme.border),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (!b.isPaid && !b.isCancelled && !b.isCompleted) ...[
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () => _payBooking(b.id),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      visualDensity: VisualDensity.compact,
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
                                const SizedBox(width: 8),
                              ],
                              if (b.canCancel) ...[
                                OutlinedButton(
                                  onPressed: () => _cancelBooking(b.id),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    side: const BorderSide(
                                      color: Colors.redAccent,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Text('Cancel Reservation'),
                                ),
                              ],
                            ],
                          ),
                        ] else if (b.isCompleted) ...[
                          const Divider(height: 20, color: AppTheme.border),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: const [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                                color: Colors.lightBlueAccent,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Session Completed',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.lightBlueAccent,
                                ),
                              ),
                            ],
                          ),
                        ] else if (b.isCancelled) ...[
                          const Divider(height: 20, color: AppTheme.border),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Icon(
                                Icons.cancel_outlined,
                                size: 16,
                                color: Colors.redAccent.withOpacity(0.85),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                b.paymentStatus.toLowerCase() == 'refunded'
                                    ? 'Cancelled & Refunded'
                                    : 'Reservation Cancelled',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.redAccent.withOpacity(0.85),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ), // Container
                  ); // InkWell
                },
              ),
            ),
    );
  }

  Widget _buildStatusBadge(String status, String paymentStatus) {
    Color bg;
    Color fg;
    String label;

    if (status.toLowerCase() == 'pending') {
      bg = Colors.orange.withOpacity(0.15);
      fg = Colors.orangeAccent;
      label = 'Pending Approval';
    } else if (status.toLowerCase() == 'cancelled') {
      bg = Colors.red.withOpacity(0.15);
      fg = Colors.redAccent;
      label =
          paymentStatus.toLowerCase() == 'refunded' ||
              paymentStatus.toLowerCase() == 'paid'
          ? 'Cancelled (Refunded)'
          : 'Cancelled';
    } else if (status.toLowerCase() == 'completed') {
      bg = Colors.blue.withOpacity(0.15);
      fg = Colors.lightBlueAccent;
      label = 'Completed';
    } else if (paymentStatus.toLowerCase() == 'paid') {
      bg = AppTheme.neonGreen.withOpacity(0.15);
      fg = AppTheme.neonGreen;
      label = 'Paid & Confirmed';
    } else if (status.toLowerCase() == 'confirmed' || status.toLowerCase() == 'accepted') {
      bg = AppTheme.neonGreen.withOpacity(0.15);
      fg = AppTheme.neonGreen;
      label = 'Accepted by Admin';
    } else {
      bg = Colors.orange.withOpacity(0.15);
      fg = Colors.orangeAccent;
      label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withOpacity(0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _buildInfoCol(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
