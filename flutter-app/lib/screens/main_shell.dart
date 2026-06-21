import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'billing_screen.dart';
import 'dashboard_screen.dart';
import 'customers_screen.dart';
import 'jobs_screen.dart';
import 'petty_cash_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  List<Widget> _getPages(bool showPettyCash, bool showBilling) {
    return [
      const DashboardScreen(),
      const JobsScreen(),
      if (showBilling) const BillingScreen(),
      const CustomersScreen(),
      if (showPettyCash) const PettyCashScreen(),
    ];
  }

  List<String> _getTitles(bool showPettyCash, bool showBilling) {
    return [
      'Dashboard',
      'Jobs',
      if (showBilling) 'Billing',
      'Customers',
      if (showPettyCash) 'Petty Cash',
    ];
  }

  void _onNavTap(int index) {
    setState(() => _selectedIndex = index);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().logout();
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final showPettyCash = user?.role != 'Waff Clerk';
    final showBilling = ['Admin', 'Super Admin', 'Manager'].contains(user?.role);
    final pages = _getPages(showPettyCash, showBilling);
    final titles = _getTitles(showPettyCash, showBilling);

    // Clamp index in case role changes
    if (_selectedIndex >= pages.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        actions: [
          if (_selectedIndex == 0)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () {},
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: _logout,
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFFF0F4F8),
        child: IndexedStack(
          index: _selectedIndex,
          children: pages,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onNavTap,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFF1D6FA4).withValues(alpha: 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 65,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: Color(0xFF1D6FA4)),
            label: 'Dashboard',
          ),
          const NavigationDestination(
            icon: Icon(Icons.work_outline),
            selectedIcon: Icon(Icons.work, color: Color(0xFF1D6FA4)),
            label: 'Jobs',
          ),
          if (showBilling)
            const NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long, color: Color(0xFF1D6FA4)),
              label: 'Billing',
            ),
          const NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people, color: Color(0xFF1D6FA4)),
            label: 'Customers',
          ),
          if (showPettyCash)
            const NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet, color: Color(0xFF1D6FA4)),
              label: 'Petty Cash',
            ),
        ],
      ),
    );
  }
}
