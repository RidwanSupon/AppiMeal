import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/admin/presentation/admin_catering_screen.dart';
import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/admin/presentation/employee_management_screen.dart';
import '../../features/admin/presentation/record_payment_dialog.dart';
import '../../features/admin/presentation/reports_screen.dart';
import '../../features/admin/presentation/settings_screen.dart';
import '../../features/auth/presentation/auth_provider.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/catering/presentation/catering_dashboard_screen.dart';
import '../../features/employee/presentation/employee_home_screen.dart';
import '../../features/employee/presentation/lunch_planning_calendar_screen.dart';
import '../../features/employee/presentation/payment_ledger_screen.dart';
import '../../features/employee/presentation/profile_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isAuth = authState.status == AuthStatus.authenticated;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isAuth && !isLoggingIn) return '/login';
      if (isAuth && isLoggingIn) return '/';

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/admin/catering',
        builder: (context, state) => const AdminCateringScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) {
          final role = authState.role ?? 'employee';

          if (role == 'catering_viewer') {
            return const CateringDashboardScreen();
          }

          if (role == 'admin' || role == 'super_admin') {
            return const AdminMainContainer();
          }

          return const EmployeeMainContainer();
        },
      ),
    ],
  );
});

// Employee Navigation Shell
class EmployeeMainContainer extends StatefulWidget {
  const EmployeeMainContainer({super.key});

  @override
  State<EmployeeMainContainer> createState() => _EmployeeMainContainerState();
}

class _EmployeeMainContainerState extends State<EmployeeMainContainer> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      EmployeeHomeScreen(onTabChange: (idx) => setState(() => _currentIndex = idx)),
      const LunchPlanningCalendarScreen(),
      const PaymentLedgerScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Lunch'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// Admin Navigation Shell
class AdminMainContainer extends StatefulWidget {
  const AdminMainContainer({super.key});

  @override
  State<AdminMainContainer> createState() => _AdminMainContainerState();
}

class _AdminMainContainerState extends State<AdminMainContainer> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      AdminDashboardScreen(onTabChange: (idx) => setState(() => _currentIndex = idx)),
      const EmployeeManagementScreen(),
      const RecordPaymentScreen(),
      const ReportsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Employees'),
          NavigationDestination(icon: Icon(Icons.payment_outlined), selectedIcon: Icon(Icons.payment), label: 'Payment'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
