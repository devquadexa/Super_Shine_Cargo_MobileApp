import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/client.dart';
import '../providers/auth_provider.dart';
import 'package:dio/dio.dart';

class PettyCashScreen extends StatefulWidget {
  const PettyCashScreen({super.key});
  @override
  State<PettyCashScreen> createState() => _PettyCashScreenState();
}

class _PettyCashScreenState extends State<PettyCashScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _assignments = [];
  List<Map<String, dynamic>> _settlements = [];
  bool _loadingAssignments = true;
  bool _loadingSettlements = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _loadData() async {
    await Future.wait([_loadAssignments(), _loadSettlements()]);
  }

  Future<void> _loadAssignments() async {
    setState(() => _loadingAssignments = true);
    try {
      final user = context.read<AuthProvider>().user;
      final endpoint = user?.role == 'Waff Clerk'
          ? '/petty-cash-assignments/my-aggregated'
          : '/petty-cash-assignments/aggregated';
      final r = await apiClient.get(endpoint);
      setState(() {
        _assignments = (r.data as List<dynamic>).cast<Map<String, dynamic>>();
        _loadingAssignments = false;
      });
    } catch (_) {
      setState(() => _loadingAssignments = false);
    }
  }

  Future<void> _loadSettlements() async {
    setState(() => _loadingSettlements = true);
    try {
      final r = await apiClient.get('/cash-balance-settlements');
      final data = r.data;
      setState(() {
        _settlements = (data['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
        _loadingSettlements = false;
      });
    } catch (_) {
      setState(() => _loadingSettlements = false);
    }
  }

  String _fmtDate(String? d) => d == null ? '-' : d.split('T').first;
  String _fmtCurrency(dynamic v) => (double.tryParse(v?.toString() ?? '') ?? 0).toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Material(
        color: Colors.white,
        child: TabBar(
          controller: _tabCtrl,
          labelColor: const Color(0xFF1D6FA4),
          unselectedLabelColor: const Color(0xFF6B7280),
          indicatorColor: const Color(0xFF1D6FA4),
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Assignments'),
            Tab(text: 'Cash Balance'),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _tabCtrl,
          children: [
            _buildAssignmentsTab(),
            _buildSettlementsTab(),
          ],
        ),
      ),
    ]);
  }

  // ── Assignments Tab ─────────────────────────────────────────────────────────
  Widget _buildAssignmentsTab() {
    if (_loadingAssignments) return const Center(child: CircularProgressIndicator());
    if (_assignments.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.account_balance_wallet_outlined, size: 48, color: Colors.grey[300]),
        const SizedBox(height: 8),
        Text('No petty cash assignments', style: TextStyle(color: Colors.grey[500])),
      ]));
    }
    return RefreshIndicator(
      onRefresh: _loadAssignments,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _assignments.length,
        itemBuilder: (_, i) => _buildAssignmentCard(_assignments[i]),
      ),
    );
  }

  Widget _buildAssignmentCard(Map<String, dynamic> group) {
    final totalAmount = double.tryParse(group['totalAssignedAmount']?.toString() ?? '0') ?? 0;
    final totalSpent = double.tryParse(group['totalActualSpent']?.toString() ?? '0') ?? 0;
    final balance = totalAmount - totalSpent;
    final assignCount = (group['assignments'] as List?)?.length ?? group['assignmentCount'] ?? 1;
    final allSettled = group['allSettled'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
            child: Text(group['jobId']?.toString() ?? '-',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1D6FA4))),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(group['assignedToName']?.toString() ?? '-',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: allSettled ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(allSettled ? 'Settled' : 'Pending',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                    color: allSettled ? const Color(0xFF059669) : const Color(0xFFD97706))),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _miniStat('Assigned', totalAmount, const Color(0xFF7C3AED)),
          const SizedBox(width: 12),
          _miniStat('Spent', totalSpent, const Color(0xFF1D6FA4)),
          const SizedBox(width: 12),
          _miniStat('Balance', balance, balance >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Text('${group['shipmentCategory'] ?? '-'}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          const Spacer(),
          Text('$assignCount assignment${assignCount > 1 ? 's' : ''}',
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ]),
      ]),
    );
  }

  // ── Settlements Tab ─────────────────────────────────────────────────────────
  Widget _buildSettlementsTab() {
    final user = context.read<AuthProvider>().user;
    final isManager = ['Admin', 'Super Admin', 'Manager'].contains(user?.role);

    if (_loadingSettlements) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _loadSettlements,
      child: _settlements.isEmpty
          ? ListView(children: [
              const SizedBox(height: 120),
              Center(child: Column(children: [
                Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 8),
                Text('No cash balance settlements', style: TextStyle(color: Colors.grey[500])),
              ])),
            ])
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _settlements.length,
              itemBuilder: (_, i) => _buildSettlementCard(_settlements[i], isManager),
            ),
    );
  }

  Widget _buildSettlementCard(Map<String, dynamic> s, bool isManager) {
    final status = s['status']?.toString() ?? 'PENDING';
    final type = s['settlementType']?.toString() ?? '-';
    final amount = double.tryParse(s['amount']?.toString() ?? '0') ?? 0;
    final statusColor = switch (status.toUpperCase()) {
      'PENDING' => const Color(0xFFD97706),
      'APPROVED' => const Color(0xFF3B82F6),
      'COMPLETED' => const Color(0xFF059669),
      'REJECTED' => const Color(0xFFEF4444),
      _ => const Color(0xFF6B7280),
    };
    final statusBg = switch (status.toUpperCase()) {
      'PENDING' => const Color(0xFFFEF3C7),
      'APPROVED' => const Color(0xFFDBEAFE),
      'COMPLETED' => const Color(0xFFD1FAE5),
      'REJECTED' => const Color(0xFFFEE2E2),
      _ => const Color(0xFFF3F4F6),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(s['userName']?.toString() ?? '-',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(10)),
            child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(4)),
            child: Text(type.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
          ),
          const Spacer(),
          Text('LKR ${_fmtCurrency(amount)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
        ]),
        if (s['notes'] != null && s['notes'].toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(s['notes'].toString(), style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ),
        const SizedBox(height: 6),
        Row(children: [
          Text(_fmtDate(s['requestDate']?.toString()), style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          const Spacer(),
          // Manager actions for pending settlements
          if (isManager && status.toUpperCase() == 'PENDING') ...[
            _actionBtn('Approve', Colors.green, () => _approveSettlement(s['settlementId'])),
            const SizedBox(width: 6),
            _actionBtn('Reject', Colors.red, () => _rejectSettlement(s['settlementId'])),
          ],
        ]),
      ]),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ),
    );
  }

  Future<void> _approveSettlement(String? id) async {
    if (id == null) return;
    try {
      await apiClient.put('/cash-balance-settlements/$id/approve', data: {'managerNotes': ''});
      _loadSettlements();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is DioException ? (e.response?.data?['message'] ?? 'Failed') : 'Failed'),
          backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _rejectSettlement(String? id) async {
    if (id == null) return;
    final notesCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Settlement', style: TextStyle(fontSize: 15)),
        content: TextField(
          controller: notesCtrl,
          decoration: const InputDecoration(labelText: 'Reason (required)', isDense: true),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || notesCtrl.text.trim().isEmpty) return;
    try {
      await apiClient.put('/cash-balance-settlements/$id/reject', data: {'managerNotes': notesCtrl.text.trim()});
      _loadSettlements();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is DioException ? (e.response?.data?['message'] ?? 'Failed') : 'Failed'),
          backgroundColor: Colors.red));
      }
    }
  }

  Widget _miniStat(String label, double value, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
      Text('LKR ${value.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    ]);
  }
}
