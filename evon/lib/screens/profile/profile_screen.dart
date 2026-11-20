import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('Driver Profile', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // User Avatar Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: AppTheme.glassCardDecoration(glow: true),
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppTheme.neonGreen.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.neonGreen, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.neonGreen.withOpacity(0.3),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      (user?.name.isNotEmpty == true) ? user!.name[0].toUpperCase() : 'U',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.neonGreen),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    user?.name ?? 'EV Driver',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: user?.role == 'super_admin'
                          ? AppTheme.purple.withOpacity(0.18)
                          : user?.role == 'station_admin'
                              ? AppTheme.neonCyan.withOpacity(0.18)
                              : AppTheme.neonGreen.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: user?.role == 'super_admin'
                            ? AppTheme.purple
                            : user?.role == 'station_admin'
                                ? AppTheme.neonCyan
                                : AppTheme.neonGreen,
                      ),
                    ),
                    child: Text(
                      user?.role.toUpperCase() ?? 'USER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: user?.role == 'super_admin'
                            ? AppTheme.purple
                            : user?.role == 'station_admin'
                                ? AppTheme.neonCyan
                                : AppTheme.neonGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Vehicle Specs Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: AppTheme.glassCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Vehicle Specifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textMain)),
                  const Divider(height: 20, color: AppTheme.border),
                  _buildSpecRow('Vehicle Type', user?.vehicleType ?? 'Electric Car'),
                  const SizedBox(height: 12),
                  _buildSpecRow('Battery Capacity', '${user?.batteryCapacity ?? 60.0} kWh'),
                  const SizedBox(height: 12),
                  _buildSpecRow('Phone Number', user?.phone.isNotEmpty == true ? user!.phone : 'Not provided'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await auth.logout();
                },
                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                label: const Text('Log Out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textMain)),
      ],
    );
  }
}
