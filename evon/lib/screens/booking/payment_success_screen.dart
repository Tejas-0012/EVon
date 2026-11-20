import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final String stationName;
  final String slotDate;
  final String slotTime;
  final double energyKwh;
  final double totalCost;
  final String bookingId;

  const PaymentSuccessScreen({
    super.key,
    required this.stationName,
    required this.slotDate,
    required this.slotTime,
    required this.energyKwh,
    required this.totalCost,
    required this.bookingId,
  });

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen>
    with SingleTickerProviderStateMixin {
  double _checkScale = 0.0;

  @override
  void initState() {
    super.initState();
    // Trigger animation after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _checkScale = 1.0);
    });
  }

  /// Dashed divider using a Row of small containers
  Widget _dashedDivider() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dashCount = (constraints.maxWidth / 10).floor();
        return Row(
          children: List.generate(dashCount, (index) {
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                height: 1,
                color: index.isEven
                    ? AppTheme.borderGlow
                    : Colors.transparent,
              ),
            );
          }),
        );
      },
    );
  }

  Widget _receiptRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textMuted,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppTheme.textMain,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shortId =
        '#${widget.bookingId.substring(0, widget.bookingId.length.clamp(0, 8)).toUpperCase()}';

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        children: [
          // Background radial glow
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.2,
                  colors: [
                    AppTheme.neonGreen.withOpacity(0.05),
                    AppTheme.bgDark,
                  ],
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                children: [
                  // ── Top section ──────────────────────────────────────────
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.38,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Animated checkmark circle
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.elasticOut,
                          width: 100 * _checkScale,
                          height: 100 * _checkScale,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.neonGreen.withOpacity(0.12),
                            border: Border.all(
                              color: AppTheme.neonGreen,
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.neonGreen.withOpacity(0.35),
                                blurRadius: 32,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.check_rounded,
                              color: AppTheme.neonGreen,
                              size: 56,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Payment Successful!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.neonGreen,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your charging slot is confirmed',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Receipt card ─────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: AppTheme.glassCardDecoration(glow: true),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.neonGreen.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.borderGlow),
                              ),
                              child: const Icon(
                                Icons.electric_bolt_rounded,
                                color: AppTheme.neonGreen,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'EVon Charging Receipt',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textMain,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _dashedDivider(),
                        const SizedBox(height: 14),

                        // Receipt rows
                        _receiptRow('Booking ID', shortId,
                            valueColor: AppTheme.neonCyan),
                        _receiptRow('Station', widget.stationName),
                        _receiptRow(
                            'Date & Time', '${widget.slotDate}  ${widget.slotTime}'),
                        _receiptRow('Energy',
                            '${widget.energyKwh.toStringAsFixed(2)} kWh'),
                        _receiptRow(
                          'Amount Paid',
                          '₹${widget.totalCost.toStringAsFixed(2)}',
                          valueColor: AppTheme.neonGreen,
                        ),

                        const SizedBox(height: 14),
                        _dashedDivider(),
                        const SizedBox(height: 20),

                        // "PAID" stamp badge — rotated, centered
                        Center(
                          child: Transform.rotate(
                            angle: -0.26, // ~-15 degrees in radians
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 28, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppTheme.neonGreen,
                                  width: 3,
                                ),
                                color: AppTheme.neonGreen.withOpacity(0.07),
                              ),
                              child: const Text(
                                'PAID',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.neonGreen,
                                  letterSpacing: 8,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Bottom buttons ────────────────────────────────────────
                  // "View My Bookings" outlined
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.popUntil(context, (r) => r.isFirst);
                        // The home screen's tab index for My Bookings can be
                        // set here if needed; for now we just go home and let
                        // the user tap the tab.
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.neonGreen,
                        side: const BorderSide(color: AppTheme.borderGlow, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'View My Bookings',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // "Back to Home" gradient
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.neonGreen.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.popUntil(context, (r) => r.isFirst);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Back to Home',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A0E17),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
