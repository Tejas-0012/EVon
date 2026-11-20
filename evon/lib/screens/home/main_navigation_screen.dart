import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../admin/station_admin_screen.dart';
import '../admin/super_admin_screen.dart';
import '../dashboard/user_dashboard_screen.dart';
import '../stations/stations_screen.dart';
import '../recommendation/route_planner_screen.dart';
import '../booking/my_bookings_screen.dart';
import '../analytics/analytics_screen.dart';
import '../profile/profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  void _onSelectTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;

    if (user?.isStationAdmin == true) {
      // Station Admin Navigation Stack
      final screens = [
        const StationAdminScreen(),
        const StationsScreen(),
        const RoutePlannerScreen(),
        const ProfileScreen(),
      ];

      return Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: IndexedStack(
          index: _currentIndex.clamp(0, screens.length - 1),
          children: screens,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex.clamp(0, screens.length - 1),
          onDestinationSelected: (index) => setState(() => _currentIndex = index),
          backgroundColor: AppTheme.bgDark,
          indicatorColor: AppTheme.neonCyan.withOpacity(0.18),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.admin_panel_settings_outlined),
              selectedIcon: Icon(Icons.admin_panel_settings_rounded, color: AppTheme.neonCyan),
              label: 'Station Console',
            ),
            NavigationDestination(
              icon: Icon(Icons.ev_station_outlined),
              selectedIcon: Icon(Icons.ev_station_rounded, color: AppTheme.neonCyan),
              label: 'Stations',
            ),
            NavigationDestination(
              icon: Icon(Icons.alt_route_outlined),
              selectedIcon: Icon(Icons.alt_route_rounded, color: AppTheme.neonCyan),
              label: 'Route Planner',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: AppTheme.neonCyan),
              label: 'Profile',
            ),
          ],
        ),
      );
    }

    if (user?.isSuperAdmin == true) {
      // Super Admin Navigation Stack
      final screens = [
        const SuperAdminScreen(),
        const StationsScreen(),
        const AnalyticsScreen(),
        const ProfileScreen(),
      ];

      return Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: IndexedStack(
          index: _currentIndex.clamp(0, screens.length - 1),
          children: screens,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex.clamp(0, screens.length - 1),
          onDestinationSelected: (index) => setState(() => _currentIndex = index),
          backgroundColor: AppTheme.bgDark,
          indicatorColor: AppTheme.purple.withOpacity(0.2),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.shield_outlined),
              selectedIcon: Icon(Icons.shield_rounded, color: AppTheme.purple),
              label: 'Super Admin',
            ),
            NavigationDestination(
              icon: Icon(Icons.ev_station_outlined),
              selectedIcon: Icon(Icons.ev_station_rounded, color: AppTheme.purple),
              label: 'Stations',
            ),
            NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics_rounded, color: AppTheme.purple),
              label: 'Grid ML',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: AppTheme.purple),
              label: 'Profile',
            ),
          ],
        ),
      );
    }

    // Default Driver / User Navigation Stack
    final screens = [
      UserDashboardScreen(onNavigateTab: _onSelectTab),
      const StationsScreen(),
      const RoutePlannerScreen(),
      const MyBookingsScreen(),
      const AnalyticsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: IndexedStack(
        index: _currentIndex.clamp(0, screens.length - 1),
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex.clamp(0, screens.length - 1),
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        backgroundColor: AppTheme.bgDark,
        indicatorColor: AppTheme.neonGreen.withOpacity(0.18),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded, color: AppTheme.neonGreen),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.ev_station_outlined),
            selectedIcon: Icon(Icons.ev_station_rounded, color: AppTheme.neonGreen),
            label: 'Stations',
          ),
          NavigationDestination(
            icon: Icon(Icons.alt_route_outlined),
            selectedIcon: Icon(Icons.alt_route_rounded, color: AppTheme.neonGreen),
            label: 'Route',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today_rounded, color: AppTheme.neonGreen),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics_rounded, color: AppTheme.neonGreen),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppTheme.neonGreen),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
