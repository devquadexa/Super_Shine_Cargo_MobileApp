import 'package:flutter/material.dart';
import '../api/accounting_service.dart';

class AccountingScreen extends StatefulWidget {
  const AccountingScreen({super.key});
  @override
  State<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends State<AccountingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _service = AccountingService();

  bool _loading = true;
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _jobFinancials = [];
  List<Map<String, dynamic>> _customerOutstanding = [];
  List<Map<String, dynamic>> _payments = [];
  bool _loadingPayments = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging && _tabCtrl.index == 3 && _loadingPayments) {
        _loadPayments();
      }
    });
    _loadDashboard();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _loadDashboard() async {
    setState(() => _loading = true);
    try {
      final data = await _service.getDashboard();
      setState(() {
        _summary = data['summary'] as Map<String, dynamic>?;
        _jobFinancials = (data['jobFinancials'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
        _customerOutstanding = (data['customerOutstanding'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadPayments() async {
    try {
      final data = await _service.getAllPayments();
      setState(() { _payments = data; _loadingPayments = false; });
    } catch (_) {
      setState(() => _loadingPayments = false);
    }
  }

  String _fmtCurrency(dynamic v) =>
      'LKR ${(double.tryParse(v?.toString() ?? '') ?? 0).toStringAsFixed(2)}';
  String _fmtDate(String? d) => d == null ? '-' : d.split('T').first;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounting'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadDashboard),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
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
                    Tab(text: 'Summary'),
                    Tab(text: 'Jobs'),
                    Tab(text: 'Customers'),
                    Tab(text: 'Payments'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildSummaryTab(),
                    _buildJobsTab(),
                    _buildCustomersTab(),
                    _buildPaymentsTab(),
                  ],
                ),
              ),
            ]),
    );
  }

  // ── Summary Tab ─────────────────────────────────────────────────────────────
  Widget _buildSummaryTab() {
    if (_summary == null) return const Center(child: Text('No data available'));
    final s = _summary!;
    final profitMargin = (double.tryParse(s['totalBillingAmount']?.toString() ?? '0') ?? 0) > 0
        ? ((double.tryParse(s['totalProfit']?.toString() ?? '0') ?? 0) /
                (double.tryParse(s['totalBillingAmount']?.toString() ?? '0') ?? 1) * 100)
            .toStringAsFixed(1)
        : '0.0';

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _statCard('Total Jobs', s['totalJobs']?.toString() ?? '0', Icons.work, const Color(0xFF1D6FA4)),
          _statCard('Petty Cash Issued', _fmtCurrency(s['totalPettyCashIssued']), Icons.account_balance_wallet, const Color(0xFF7C3AED)),
          _statCard('Total Actual Cost', _fmtCurrency(s['totalActualCost']), Icons.receipt, const Color(0xFF6B7280)),
          _statCard('Total Billing', _fmtCurrency(s['totalBillingAmount']), Icons.request_quote, const Color(0xFF1D6FA4)),
          _statCard('Total Profit', _fmtCurrency(s['totalProfit']), Icons.trending_up, const Color(0xFF059669)),
          _statCard('Profit Margin', '$profitMargin%', Icons.pie_chart, const Color(0xFF059669)),
          const SizedBox(height: 12),
          const Text('Payment Status', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _miniCard('Paid', '${s['paidJobsCount'] ?? 0}', _fmtCurrency(s['totalPaid']), const Color(0xFF059669))),
            const SizedBox(width: 8),
            Expanded(child: _miniCard('Unpaid', '${s['unpaidJobsCount'] ?? 0}', _fmtCurrency(s['totalOutstanding']), const Color(0xFFD97706))),
            const SizedBox(width: 8),
            Expanded(child: _miniCard('Overdue', '${s['overdueJobsCount'] ?? 0}', _fmtCurrency(s['totalOverdue']), const Color(0xFFEF4444))),
          ]),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }

  Widget _miniCard(String title, String count, String amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Text(count, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 2),
        Text(title, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(amount, style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.8))),
      ]),
    );
  }

  // ── Jobs Tab ────────────────────────────────────────────────────────────────
  Widget _buildJobsTab() {
    if (_jobFinancials.isEmpty) {
      return Center(child: Text('No job financial data', style: TextStyle(color: Colors.grey[500])));
    }
    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _jobFinancials.length,
        itemBuilder: (_, i) => _buildJobCard(_jobFinancials[i]),
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final billing = double.tryParse(job['billingAmount']?.toString() ?? '0') ?? 0;
    final profit = double.tryParse(job['profit']?.toString() ?? '0') ?? 0;
    final isPaid = job['isPaid'] == true;
    final isOverdue = job['isOverdue'] == true;
    final overdueDays = job['overdueDays'] ?? 0;

    Color statusColor;
    String statusLabel;
    if (billing == 0) {
      statusColor = const Color(0xFF6B7280);
      statusLabel = 'Not Billed';
    } else if (isPaid) {
      statusColor = const Color(0xFF059669);
      statusLabel = 'Paid';
    } else if (isOverdue) {
      statusColor = const Color(0xFFEF4444);
      statusLabel = 'Overdue';
    } else {
      statusColor = const Color(0xFFD97706);
      statusLabel = 'Pending';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOverdue ? const Color(0xFFFEF2F2) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isOverdue ? const Color(0xFFFECACA) : const Color(0xFFE5E7EB)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
            child: Text(job['jobId']?.toString() ?? '-',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1D6FA4))),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(job['customerName']?.toString() ?? '-',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _jobStat('Billing', _fmtCurrency(billing), const Color(0xFF1D6FA4)),
          const SizedBox(width: 10),
          _jobStat('Cost', _fmtCurrency(job['actualCost']), const Color(0xFF6B7280)),
          const SizedBox(width: 10),
          _jobStat('Profit', _fmtCurrency(profit), profit >= 0 ? const Color(0xFF059669) : const Color(0xFFEF4444)),
        ]),
        if (isOverdue && overdueDays > 0) ...[
          const SizedBox(height: 6),
          Text('⚠ Overdue by $overdueDays days', style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444), fontWeight: FontWeight.w500)),
        ],
      ]),
    );
  }

  Widget _jobStat(String label, String value, Color color) {
    return Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[500])),
      Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    ]));
  }

  // ── Customers Tab ───────────────────────────────────────────────────────────
  Widget _buildCustomersTab() {
    if (_customerOutstanding.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.check_circle_outline, size: 48, color: Colors.green[300]),
        const SizedBox(height: 8),
        Text('No outstanding payments', style: TextStyle(color: Colors.grey[500])),
        Text('All customers are up to date', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
      ]));
    }

    // Sort by total outstanding descending
    final sorted = List<Map<String, dynamic>>.from(_customerOutstanding)
      ..sort((a, b) => ((double.tryParse(b['totalOutstanding']?.toString() ?? '0') ?? 0) -
              (double.tryParse(a['totalOutstanding']?.toString() ?? '0') ?? 0))
          .toInt());

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: sorted.length,
        itemBuilder: (_, i) => _buildCustomerCard(sorted[i]),
      ),
    );
  }

  Widget _buildCustomerCard(Map<String, dynamic> c) {
    final outstanding = double.tryParse(c['totalOutstanding']?.toString() ?? '0') ?? 0;
    final overdue = double.tryParse(c['overdueAmount']?.toString() ?? '0') ?? 0;
    final unpaidJobs = c['unpaidJobsCount'] ?? 0;
    final overdueJobs = c['overdueJobsCount'] ?? 0;
    final creditDays = c['creditPeriodDays'] ?? 30;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: overdue > 0 ? const Color(0xFFFEF2F2) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: overdue > 0 ? const Color(0xFFFECACA) : const Color(0xFFE5E7EB)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(c['customerName']?.toString() ?? '-',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          Text('Credit: $creditDays days', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Outstanding', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            Text(_fmtCurrency(outstanding),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFD97706))),
          ])),
          if (overdue > 0)
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Overdue', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              Text(_fmtCurrency(overdue),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
            ])),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          _badge('$unpaidJobs unpaid', const Color(0xFFD97706)),
          const SizedBox(width: 8),
          if (overdueJobs > 0) _badge('$overdueJobs overdue', const Color(0xFFEF4444)),
        ]),
      ]),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  // ── Payments Tab ────────────────────────────────────────────────────────────
  Widget _buildPaymentsTab() {
    if (_loadingPayments) {
      _loadPayments();
      return const Center(child: CircularProgressIndicator());
    }
    if (_payments.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.payment_outlined, size: 48, color: Colors.grey[300]),
        const SizedBox(height: 8),
        Text('No payment records', style: TextStyle(color: Colors.grey[500])),
      ]));
    }

    // Group by payment method
    final cheques = _payments.where((p) => p['paymentMethod'] == 'Cheque').toList();
    final bankTransfers = _payments.where((p) => p['paymentMethod'] == 'Bank Transfer').toList();
    final cashPayments = _payments.where((p) => p['paymentMethod'] == 'Cash').toList();

    final chequeTotal = cheques.fold<double>(0, (s, p) => s + (double.tryParse(p['amount']?.toString() ?? '0') ?? 0));
    final bankTotal = bankTransfers.fold<double>(0, (s, p) => s + (double.tryParse(p['amount']?.toString() ?? '0') ?? 0));
    final cashTotal = cashPayments.fold<double>(0, (s, p) => s + (double.tryParse(p['amount']?.toString() ?? '0') ?? 0));

    return RefreshIndicator(
      onRefresh: () async { setState(() => _loadingPayments = true); await _loadPayments(); },
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Summary row
          Row(children: [
            Expanded(child: _paymentSummaryChip('Cheques', cheques.length, chequeTotal, const Color(0xFF7C3AED))),
            const SizedBox(width: 8),
            Expanded(child: _paymentSummaryChip('Bank', bankTransfers.length, bankTotal, const Color(0xFF1D6FA4))),
            const SizedBox(width: 8),
            Expanded(child: _paymentSummaryChip('Cash', cashPayments.length, cashTotal, const Color(0xFF059669))),
          ]),
          const SizedBox(height: 16),

          // Cheques section
          if (cheques.isNotEmpty) ...[
            _sectionHeader('Cheque Payments', cheques.length),
            ...cheques.take(10).map((p) => _buildPaymentCard(p, const Color(0xFF7C3AED))),
            if (cheques.length > 10)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('+ ${cheques.length - 10} more...', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ),
          ],

          // Bank transfers section
          if (bankTransfers.isNotEmpty) ...[
            _sectionHeader('Bank Transfers', bankTransfers.length),
            ...bankTransfers.take(10).map((p) => _buildPaymentCard(p, const Color(0xFF1D6FA4))),
            if (bankTransfers.length > 10)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('+ ${bankTransfers.length - 10} more...', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ),
          ],

          // Cash section
          if (cashPayments.isNotEmpty) ...[
            _sectionHeader('Cash Payments', cashPayments.length),
            ...cashPayments.take(10).map((p) => _buildPaymentCard(p, const Color(0xFF059669))),
            if (cashPayments.length > 10)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('+ ${cashPayments.length - 10} more...', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ),
          ],
        ],
      ),
    );
  }

  Widget _paymentSummaryChip(String label, int count, double total, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Text('$count', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(_fmtCurrency(total), style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.7))),
      ]),
    );
  }

  Widget _sectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(children: [
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
          child: Text('$count', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
        ),
      ]),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> p, Color accent) {
    final amount = double.tryParse(p['amount']?.toString() ?? '0') ?? 0;
    final status = p['status']?.toString() ?? 'Pending';
    final statusColor = switch (status.toLowerCase()) {
      'cleared' => const Color(0xFF059669),
      'pending' => const Color(0xFFD97706),
      'bounced' => const Color(0xFFEF4444),
      _ => const Color(0xFF6B7280),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(children: [
        Container(
          width: 4, height: 36,
          decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(p['customerName']?.toString() ?? '-', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(_fmtCurrency(amount), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: accent)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Text(p['jobId']?.toString() ?? '-', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            const SizedBox(width: 8),
            Text(_fmtDate(p['paymentDate']?.toString()), style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: statusColor)),
            ),
          ]),
        ])),
      ]),
    );
  }
}
