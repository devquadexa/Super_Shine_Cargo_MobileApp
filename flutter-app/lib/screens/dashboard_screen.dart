import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../api/client.dart';
import 'package:dio/dio.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  String? _error;

  // Stats
  int totalCustomers = 0;
  int totalJobs = 0;
  int openJobs = 0;
  int closedJobs = 0;
  int unpaidBills = 0;
  int paidBills = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch customers and jobs in parallel
      final results = await Future.wait([
        apiClient.get('/customers'),
        apiClient.get('/jobs'),
        apiClient.get('/billing'),
      ]);

      final customers = results[0].data as List<dynamic>;
      final jobs = results[1].data as List<dynamic>;
      final bills = results[2].data as List<dynamic>;

      setState(() {
        totalCustomers = customers.length;
        totalJobs = jobs.length;
        openJobs = jobs
            .where((j) =>
                (j['status'] ?? '').toString().toLowerCase() == 'open')
            .length;
        closedJobs = jobs
            .where((j) =>
                (j['status'] ?? '').toString().toLowerCase() == 'closed')
            .length;
        unpaidBills = bills
            .where((b) =>
                (b['paymentStatus'] ?? '').toString().toLowerCase() ==
                'unpaid')
            .length;
        paidBills = bills
            .where((b) =>
                (b['paymentStatus'] ?? '').toString().toLowerCase() == 'paid')
            .length;
        _isLoading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data?['message'] ?? 'Failed to load dashboard data.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Unexpected error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    // Logout is handled by MainShell
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1D6FA4), Color(0xFF1A5F8F)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1D6FA4).withOpacity(0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.8), fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.fullName ?? 'User',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        user?.role ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Stats section
              const Text(
                'Overview',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D6FA4)),
              ),
              const SizedBox(height: 12),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_error != null)
                _ErrorCard(message: _error!, onRetry: _loadStats)
              else
                Column(
                  children: [
                    // Row 1
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Customers',
                            value: totalCustomers,
                            icon: Icons.people_outline,
                            color: const Color(0xFF3B82F6), // blue
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'Total Jobs',
                            value: totalJobs,
                            icon: Icons.work_outline,
                            color: const Color(0xFF8B5CF6), // purple
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Row 2
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Open Jobs',
                            value: openJobs,
                            icon: Icons.pending_outlined,
                            color: const Color(0xFFF59E0B), // amber
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'Closed Jobs',
                            value: closedJobs,
                            icon: Icons.check_circle_outline,
                            color: const Color(0xFF10B981), // green
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Row 3
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Unpaid Bills',
                            value: unpaidBills,
                            icon: Icons.receipt_long_outlined,
                            color: const Color(0xFFEF4444), // red
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'Paid Bills',
                            value: paidBills,
                            icon: Icons.paid_outlined,
                            color: const Color(0xFF10B981), // green
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: const Border(
          left: BorderSide(color: Color(0xFFE5E7EB)),
          right: BorderSide(color: Color(0xFFE5E7EB)),
          top: BorderSide(color: Color(0xFFE5E7EB)),
          bottom: BorderSide(color: Color(0xFFE5E7EB)),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D6FA4).withOpacity(0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3),
              ),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value.toString(),
            style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: color,
                height: 1.1),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        children: [
          const Icon(Icons.wifi_off, color: Colors.red, size: 40),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
