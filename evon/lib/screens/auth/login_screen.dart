import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController(text: 'user@evon.com');
  final _passCtrl = TextEditingController(text: 'user123');
  bool _obscure = true;
  String? _errorMessage;

  // 0: Driver (User), 1: Station Admin, 2: Super Admin
  int _selectedRoleIndex = 0;
  int _selectedStationAdminSubIndex = 0;

  final List<Map<String, dynamic>> _roles = [
    {
      'role': 'user',
      'label': 'EV Driver',
      'icon': Icons.directions_car_rounded,
      'title': 'EV Driver / User',
      'subtitle': 'Search stations, check battery range & book charging slots',
      'email': 'user@evon.com',
      'password': 'user123',
    },
    {
      'role': 'station_admin',
      'label': 'Station Admin',
      'icon': Icons.ev_station_rounded,
      'title': 'Station Administrator',
      'subtitle': 'Assigned to a specific station — accept bookings & view load',
      'subAdmins': [
        {
          'label': 'Station 1: EVon Hub',
          'stationName': 'EVon Charging Hub (IoT Testbed)',
          'email': 'station1@evon.com',
          'password': 'station123',
        },
        {
          'label': 'Station 2: Aloft ORR',
          'stationName': 'Aloft Bengaluru Outer Ring Road',
          'email': 'station2@evon.com',
          'password': 'station123',
        },
        {
          'label': 'Station 3: Akshaya',
          'stationName': 'Akshaya Motors Mercedes-Benz',
          'email': 'station3@evon.com',
          'password': 'station123',
        },
      ],
    },
    {
      'role': 'super_admin',
      'label': 'Super Admin',
      'icon': Icons.shield_rounded,
      'title': 'Central Super Administrator',
      'subtitle': 'Create station admins, assign stations & monitor grid ML',
      'email': 'superadmin@evon.com',
      'password': 'admin123',
    },
  ];

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _onRoleTabSelected(int index) {
    setState(() {
      _selectedRoleIndex = index;
      _errorMessage = null;

      if (index == 0) {
        _emailCtrl.text = 'user@evon.com';
        _passCtrl.text = 'user123';
      } else if (index == 1) {
        final sub = _roles[1]['subAdmins'][_selectedStationAdminSubIndex];
        _emailCtrl.text = sub['email'];
        _passCtrl.text = sub['password'];
      } else if (index == 2) {
        _emailCtrl.text = 'superadmin@evon.com';
        _passCtrl.text = 'admin123';
      }
    });
  }

  void _onStationAdminSubSelected(int subIndex) {
    setState(() {
      _selectedStationAdminSubIndex = subIndex;
      final sub = _roles[1]['subAdmins'][subIndex];
      _emailCtrl.text = sub['email'];
      _passCtrl.text = sub['password'];
      _errorMessage = null;
    });
  }

  Future<void> _handleLogin() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter both email and password');
      return;
    }

    setState(() => _errorMessage = null);

    final auth = Provider.of<AuthService>(context, listen: false);
    final success = await auth.login(email, password);

    if (!success && mounted) {
      setState(() => _errorMessage = 'Invalid email or password. Ensure backend is running.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        children: [
          // Background Glows matching style.css .evon-glow-1 & .evon-glow-2
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.neonGreen.withOpacity(0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.electricBlue.withOpacity(0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Section
                      Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.neonGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: const Text(
                                'SECURE ACCESS',
                                style: TextStyle(
                                  color: AppTheme.neonGreen,
                                  fontSize: 11,
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.bolt_rounded, color: AppTheme.neonGreen, size: 36),
                                const SizedBox(width: 4),
                                ShaderMask(
                                  shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                                  child: const Text(
                                    'EVon',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 34,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Smart EV Charging Management System',
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Primary 3-Role Switcher (Driver, Station Admin, Super Admin)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          children: List.generate(_roles.length, (i) {
                            final isSel = _selectedRoleIndex == i;
                            final r = _roles[i];
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => _onRoleTabSelected(i),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    gradient: isSel ? AppTheme.primaryGradient : null,
                                    color: isSel ? null : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        r['icon'] as IconData,
                                        size: 15,
                                        color: isSel ? const Color(0xFF0A0E17) : AppTheme.textMuted,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        r['label'] as String,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isSel ? const Color(0xFF0A0E17) : AppTheme.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // If Station Admin is selected, show the 3 Specific Station Admin options
                      if (_selectedRoleIndex == 1) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.bgCard.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.neonCyan.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(left: 4, bottom: 6),
                                child: Text(
                                  'Select Station Admin Account:',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.neonCyan),
                                ),
                              ),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: List.generate(
                                    (_roles[1]['subAdmins'] as List).length,
                                    (subI) {
                                      final isSubSel = _selectedStationAdminSubIndex == subI;
                                      final sub = (_roles[1]['subAdmins'] as List)[subI];
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: ChoiceChip(
                                          label: Text(sub['label'] as String),
                                          selected: isSubSel,
                                          onSelected: (_) => _onStationAdminSubSelected(subI),
                                          selectedColor: AppTheme.neonCyan.withOpacity(0.2),
                                          backgroundColor: AppTheme.bgDark,
                                          labelStyle: TextStyle(
                                            fontSize: 11,
                                            fontWeight: isSubSel ? FontWeight.bold : FontWeight.normal,
                                            color: isSubSel ? AppTheme.neonCyan : AppTheme.textMuted,
                                          ),
                                          side: BorderSide(
                                            color: isSubSel ? AppTheme.neonCyan : AppTheme.border,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Role Description Banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedRoleIndex == 2
                              ? AppTheme.purple.withOpacity(0.12)
                              : _selectedRoleIndex == 1
                                  ? AppTheme.neonCyan.withOpacity(0.1)
                                  : AppTheme.neonGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _selectedRoleIndex == 2
                                ? AppTheme.purple.withOpacity(0.4)
                                : _selectedRoleIndex == 1
                                    ? AppTheme.neonCyan.withOpacity(0.4)
                                    : AppTheme.neonGreen.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _roles[_selectedRoleIndex]['icon'] as IconData,
                              size: 18,
                              color: _selectedRoleIndex == 2
                                  ? AppTheme.purple
                                  : _selectedRoleIndex == 1
                                      ? AppTheme.neonCyan
                                      : AppTheme.neonGreen,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _roles[_selectedRoleIndex]['title'] as String,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _selectedRoleIndex == 2
                                        ? AppTheme.purple
                                        : _selectedRoleIndex == 1
                                            ? AppTheme.neonCyan
                                            : AppTheme.neonGreen,
                                    ),
                                  ),
                                  Text(
                                    _roles[_selectedRoleIndex]['subtitle'] as String,
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Form Glass Container
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: AppTheme.glassCardDecoration(glow: true),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_errorMessage != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade900.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.red.shade400.withOpacity(0.5)),
                                ),
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                              ),

                            // Role helper badge
                            Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: AppTheme.bgDark,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.key_rounded, color: AppTheme.neonGreen, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Credentials: ${_emailCtrl.text} / ${_passCtrl.text}',
                                      style: const TextStyle(
                                        color: AppTheme.textMuted,
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Email input
                            TextField(
                              controller: _emailCtrl,
                              style: const TextStyle(color: AppTheme.textMain),
                              decoration: const InputDecoration(
                                labelText: 'Email Address',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Password input
                            TextField(
                              controller: _passCtrl,
                              obscureText: _obscure,
                              style: const TextStyle(color: AppTheme.textMain),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscure ? Icons.visibility_off : Icons.visibility,
                                    color: AppTheme.textDim,
                                  ),
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Gradient Neon Button
                            Container(
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.neonGreen.withOpacity(0.35),
                                    blurRadius: 18,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: auth.isLoading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: auth.isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: Color(0xFF0A0E17),
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Text(
                                        'Sign In to EVon',
                                        style: TextStyle(
                                          color: Color(0xFF0A0E17),
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Register Link
                      // Bottom Context Information
                      if (_selectedRoleIndex == 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "New EV Driver? ",
                              style: TextStyle(color: AppTheme.textMuted),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                );
                              },
                              child: const Text(
                                'Register Account',
                                style: TextStyle(
                                  color: AppTheme.neonGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else if (_selectedRoleIndex == 1) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.lock_person_rounded, size: 14, color: AppTheme.textMuted),
                            SizedBox(width: 6),
                            Text(
                              'Station Admins are provisioned exclusively by Super Admin.',
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.shield_outlined, size: 14, color: AppTheme.purple),
                            SizedBox(width: 6),
                            Text(
                              'Super Admin console with central station admin provisioning.',
                              style: TextStyle(color: AppTheme.purple, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
