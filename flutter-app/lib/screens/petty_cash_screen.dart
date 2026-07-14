import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/client.dart';
import '../api/cash_withdrawal_service.dart';
import '../providers/auth_provider.dart';
import 'package:dio/dio.dart';
import 'expenses_screen.dart';

class PettyCashScreen extends StatefulWidget {
  const PettyCashScreen({super.key});
  @override
  State<PettyCashScreen> createState() => _PettyCashScreenState();
}

class _PettyCashScreenState extends State<PettyCashScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _assignments = [];
  List<Map<String, dynamic>> _settlements = [];
  List<Map<String, dynamic>> _withdrawals = [];
  bool _loadingAssignments = true;
  bool _loadingSettlements = true;
  bool _loadingWithdrawals = true;
  double _overallBalance = 0;

  final _withdrawalService = CashWithdrawalService();

  // Filter state for withdrawals
  int _filterMonth = DateTime.now().month;
  int _filterYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _tabCtrl.addListener(() {
      // Force rebuild when tab changes to ensure content loads
      if (!_tabCtrl.indexIsChanging) {
        setState(() {});
      }
    });
    _loadData();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _loadData() async {
    await Future.wait([_loadAssignments(), _loadSettlements(), _loadWithdrawals(), _loadBalance()]);
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

  Future<void> _loadWithdrawals() async {
    setState(() => _loadingWithdrawals = true);
    try {
      final data = await _withdrawalService.getAll();
      setState(() {
        _withdrawals = data;
        _loadingWithdrawals = false;
      });
    } catch (_) {
      setState(() => _loadingWithdrawals = false);
    }
  }

  Future<void> _loadBalance() async {
    try {
      final r = await apiClient.get('/petty-cash/balance');
      setState(() => _overallBalance = (double.tryParse(r.data['balance']?.toString() ?? '0') ?? 0));
    } catch (_) {}
  }

  List<Map<String, dynamic>> get _filteredWithdrawals {
    return _withdrawals.where((w) {
      final dateStr = w['withdrawalDate']?.toString();
      if (dateStr == null) return false;
      final date = DateTime.tryParse(dateStr);
      if (date == null) return false;
      return date.month == _filterMonth && date.year == _filterYear;
    }).toList();
  }

  String _fmtDate(String? d) => d == null ? '-' : d.split('T').first;
  String _fmtCurrency(dynamic v) => (double.tryParse(v?.toString() ?? '') ?? 0).toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    final isAdmin = ['Admin', 'Super Admin'].contains(user?.role);

    return Column(children: [
      Material(
        color: Colors.white,
        child: TabBar(
          controller: _tabCtrl,
          labelColor: const Color(0xFF1D6FA4),
          unselectedLabelColor: const Color(0xFF6B7280),
          indicatorColor: const Color(0xFF1D6FA4),
          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          isScrollable: false,
          tabs: const [
            Tab(text: 'Assignments'),
            Tab(text: 'Balance'),
            Tab(text: 'Deposits'),
            Tab(text: 'Expenses'),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _tabCtrl,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildAssignmentsTab(),
            _buildSettlementsTab(),
            _buildWithdrawalsTab(isAdmin),
            const ExpensesScreen(),
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
          if (isManager && status.toUpperCase() == 'PENDING') ...[
            _actionBtn('Approve', Colors.green, () => _approveSettlement(s['settlementId'])),
            const SizedBox(width: 6),
            _actionBtn('Reject', Colors.red, () => _rejectSettlement(s['settlementId'])),
          ],
        ]),
      ]),
    );
  }

  // ── Deposits & Withdrawals Tab ──────────────────────────────────────────────
  Widget _buildWithdrawalsTab(bool isAdmin) {
    if (_loadingWithdrawals) return const Center(child: CircularProgressIndicator());

    final filtered = _filteredWithdrawals;
    final totalWithdrawals = filtered
        .where((w) => (w['transactionType'] ?? 'withdrawal') == 'withdrawal')
        .fold<double>(0, (sum, w) => sum + (double.tryParse(w['amount']?.toString() ?? '0') ?? 0));
    final totalDeposits = filtered
        .where((w) => w['transactionType'] == 'deposit')
        .fold<double>(0, (sum, w) => sum + (double.tryParse(w['amount']?.toString() ?? '0') ?? 0));

    return RefreshIndicator(
      onRefresh: () async {
        await _loadWithdrawals();
        await _loadBalance();
      },
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Balance card
          _buildBalanceSummaryCard(totalWithdrawals, totalDeposits),
          const SizedBox(height: 12),
          // Month/Year filter
          _buildMonthFilter(),
          const SizedBox(height: 12),
          // Add button (Admin/Super Admin only)
          if (isAdmin) ...[
            _buildRecordButton(),
            const SizedBox(height: 12),
          ],
          // List of transactions
          if (filtered.isEmpty)
            _buildEmptyState()
          else
            ...filtered.map((w) => _buildWithdrawalCard(w)),
        ],
      ),
    );
  }

  Widget _buildBalanceSummaryCard(double totalWithdrawals, double totalDeposits) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D6FA4), Color(0xFF2E8BC0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Petty Cash Balance', style: TextStyle(fontSize: 11, color: Colors.white70)),
        const SizedBox(height: 4),
        Text('LKR ${_fmtCurrency(_overallBalance)}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _summaryChip(
            icon: Icons.arrow_downward_rounded,
            label: 'Withdrawals',
            value: totalWithdrawals,
            color: const Color(0xFF10B981),
          )),
          const SizedBox(width: 10),
          Expanded(child: _summaryChip(
            icon: Icons.arrow_upward_rounded,
            label: 'Deposits',
            value: totalDeposits,
            color: const Color(0xFFF59E0B),
          )),
        ]),
      ]),
    );
  }

  Widget _summaryChip({required IconData icon, required String label, required double value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.white70)),
          Text('LKR ${_fmtCurrency(value)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
        ])),
      ]),
    );
  }

  Widget _buildMonthFilter() {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(children: [
        const Icon(Icons.filter_list, size: 16, color: Color(0xFF6B7280)),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _filterMonth,
              isDense: true,
              style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
              items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(months[i]))),
              onChanged: (v) { if (v != null) setState(() => _filterMonth = v); },
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _filterYear,
              isDense: true,
              style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
              items: List.generate(5, (i) {
                final y = DateTime.now().year - 2 + i;
                return DropdownMenuItem(value: y, child: Text('$y'));
              }),
              onChanged: (v) { if (v != null) setState(() => _filterYear = v); },
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildRecordButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _showRecordDialog,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Record Transaction', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1D6FA4),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(child: Column(children: [
        Icon(Icons.account_balance_outlined, size: 48, color: Colors.grey[300]),
        const SizedBox(height: 8),
        Text('No transactions for this month', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
      ])),
    );
  }

  Widget _buildWithdrawalCard(Map<String, dynamic> w) {
    final type = w['transactionType']?.toString() ?? 'withdrawal';
    final isDeposit = type == 'deposit';
    final amount = double.tryParse(w['amount']?.toString() ?? '0') ?? 0;
    final bankName = w['bankName']?.toString() ?? '-';
    final date = _fmtDate(w['withdrawalDate']?.toString());
    final notes = w['notes']?.toString() ?? '';
    final createdByName = w['createdByName']?.toString() ?? w['createdBy']?.toString() ?? '-';
    final wId = w['withdrawalId']?.toString() ?? '-';

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
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDeposit ? const Color(0xFFFEF3C7) : const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              isDeposit ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 16,
              color: isDeposit ? const Color(0xFFD97706) : const Color(0xFF059669),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isDeposit ? 'Deposit' : 'Withdrawal',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Text(bankName, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ])),
          Text('LKR ${_fmtCurrency(amount)}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                  color: isDeposit ? const Color(0xFFD97706) : const Color(0xFF059669))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Text(wId, style: TextStyle(fontSize: 10, color: Colors.grey[400], fontFamily: 'monospace')),
          const Spacer(),
          Text(date, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ]),
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(notes, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
        const SizedBox(height: 4),
        Text('Recorded by: $createdByName', style: TextStyle(fontSize: 10, color: Colors.grey[400])),
      ]),
    );
  }

  // ── Record Transaction Dialog ───────────────────────────────────────────────
  void _showRecordDialog() {
    final formKey = GlobalKey<FormState>();
    String transactionType = 'withdrawal';
    final amountCtrl = TextEditingController();
    String bankName = '';
    final dateCtrl = TextEditingController(text: DateTime.now().toIso8601String().split('T').first);
    final notesCtrl = TextEditingController();
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(children: [
                    const Text('Record Transaction',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  // Transaction Type
                  const Text('Transaction Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _typeOption(
                      label: 'Withdrawal',
                      icon: Icons.arrow_downward_rounded,
                      selected: transactionType == 'withdrawal',
                      color: const Color(0xFF059669),
                      onTap: () => setModalState(() => transactionType = 'withdrawal'),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _typeOption(
                      label: 'Deposit',
                      icon: Icons.arrow_upward_rounded,
                      selected: transactionType == 'deposit',
                      color: const Color(0xFFD97706),
                      onTap: () => setModalState(() => transactionType = 'deposit'),
                    )),
                  ]),
                  const SizedBox(height: 16),

                  // Amount
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount *',
                      prefixText: 'LKR ',
                      isDense: true,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      final n = double.tryParse(v);
                      if (n == null || n <= 0) return 'Enter a valid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Bank Name
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Bank Name *', isDense: true),
                    items: const [
                      DropdownMenuItem(value: 'Commercial Bank', child: Text('Commercial Bank')),
                      DropdownMenuItem(value: 'Hatton National Bank', child: Text('Hatton National Bank')),
                      DropdownMenuItem(value: 'Sampath Bank', child: Text('Sampath Bank')),
                    ],
                    onChanged: (v) => setModalState(() => bankName = v ?? ''),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),

                  // Date
                  TextFormField(
                    controller: dateCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Transaction Date *',
                      suffixIcon: Icon(Icons.calendar_today, size: 18),
                      isDense: true,
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (picked != null) {
                        setModalState(() => dateCtrl.text = picked.toIso8601String().split('T').first);
                      }
                    },
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),

                  // Notes
                  TextFormField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: submitting ? null : () async {
                        if (!formKey.currentState!.validate()) return;
                        setModalState(() => submitting = true);
                        try {
                          await _withdrawalService.create(
                            amount: double.parse(amountCtrl.text),
                            bankName: bankName,
                            withdrawalDate: dateCtrl.text,
                            transactionType: transactionType,
                            notes: notesCtrl.text.trim(),
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          _loadWithdrawals();
                          _loadBalance();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('${transactionType == 'deposit' ? 'Deposit' : 'Withdrawal'} recorded'),
                              backgroundColor: const Color(0xFF059669),
                            ));
                          }
                        } catch (e) {
                          setModalState(() => submitting = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                              content: Text(e is DioException
                                  ? (e.response?.data?['message'] ?? 'Failed to record')
                                  : 'Failed to record'),
                              backgroundColor: Colors.red,
                            ));
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: transactionType == 'deposit'
                            ? const Color(0xFFD97706) : const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: submitting
                          ? const SizedBox(height: 18, width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(
                              'Record ${transactionType == 'deposit' ? 'Deposit' : 'Withdrawal'}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              )),
            ),
          );
        },
      ),
    );
  }

  Widget _typeOption({
    required String label,
    required IconData icon,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? color : const Color(0xFFE5E7EB), width: selected ? 2 : 1),
        ),
        child: Column(children: [
          Icon(icon, color: selected ? color : Colors.grey, size: 20),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: selected ? color : Colors.grey[600],
          )),
        ]),
      ),
    );
  }

  // ── Shared Helpers ──────────────────────────────────────────────────────────

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
