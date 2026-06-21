import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/billing_service.dart';
import '../api/client.dart';
import '../providers/auth_provider.dart';
import 'billing_detail_screen.dart';
import 'billing_job_screen.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});
  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen>
    with SingleTickerProviderStateMixin {
  final _service = BillingService();
  late TabController _tabCtrl;

  List<Map<String, dynamic>> _bills = [];
  List<Map<String, dynamic>> _filteredBills = [];
  bool _loadingBills = true;
  String _search = '';
  String _statusFilter = 'All';

  static const _statuses = ['All', 'Unpaid', 'Partially Paid', 'Paid', 'Overdue'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadBills();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _loadBills() async {
    setState(() => _loadingBills = true);
    try {
      final bills = await _service.getBills();
      setState(() {
        _bills = bills;
        _applyFilter();
        _loadingBills = false;
      });
    } catch (_) {
      setState(() => _loadingBills = false);
    }
  }

  void _applyFilter() {
    final q = _search.toLowerCase();
    setState(() {
      _filteredBills = _bills.where((b) {
        final s = b['paymentStatus']?.toString() ?? 'Unpaid';
        final isOverdue = b['isOverdue'] == true || b['isOverdue'] == 1;
        final displayStatus = (s == 'Unpaid' && isOverdue) ? 'Overdue' : s;
        final matchStatus = _statusFilter == 'All' || displayStatus == _statusFilter;
        final matchSearch = q.isEmpty ||
            (b['jobId']?.toString().toLowerCase().contains(q) ?? false) ||
            (b['invoiceNumber']?.toString().toLowerCase().contains(q) ?? false) ||
            (b['customerName']?.toString().toLowerCase().contains(q) ?? false) ||
            (b['customerId']?.toString().toLowerCase().contains(q) ?? false);
        return matchStatus && matchSearch;
      }).toList();
    });
  }

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
          tabs: const [Tab(text: 'Invoices'), Tab(text: 'New Invoice')],
        ),
      ),
      Expanded(child: TabBarView(controller: _tabCtrl, children: [
        _buildInvoicesTab(),
        BillingJobScreen(onInvoiceGenerated: () {
          _loadBills();
          _tabCtrl.animateTo(0);
        }),
      ])),
    ]);
  }

  // ── Invoices Tab ─────────────────────────────────────────────────────────────
  Widget _buildInvoicesTab() {
    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by job, invoice, customer...',
              hintStyle: const TextStyle(fontSize: 13),
              prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF9CA3AF)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            ),
            onChanged: (v) { _search = v; _applyFilter(); },
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _statuses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final s = _statuses[i];
                final active = s == _statusFilter;
                return GestureDetector(
                  onTap: () { setState(() => _statusFilter = s); _applyFilter(); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: active ? const Color(0xFF1D6FA4) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(s, style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: active ? Colors.white : const Color(0xFF6B7280))),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
      Expanded(
        child: _loadingBills
            ? const Center(child: CircularProgressIndicator())
            : _filteredBills.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Text('No invoices found', style: TextStyle(color: Colors.grey[500])),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => _tabCtrl.animateTo(1),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Create Invoice'),
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF1D6FA4)),
                    ),
                  ]))
                : RefreshIndicator(
                    onRefresh: _loadBills,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _filteredBills.length,
                      itemBuilder: (_, i) => _buildBillCard(_filteredBills[i]),
                    ),
                  ),
      ),
    ]);
  }

  Widget _buildBillCard(Map<String, dynamic> b) {
    final status = b['paymentStatus']?.toString() ?? 'Unpaid';
    final isOverdue = b['isOverdue'] == true || b['isOverdue'] == 1;
    final displayStatus = (status == 'Unpaid' && isOverdue) ? 'Overdue' : status;
    final netTotal = double.tryParse(b['netTotal']?.toString() ?? b['billingAmount']?.toString() ?? '0') ?? 0;
    final paidAmount = double.tryParse(b['paidAmount']?.toString() ?? '0') ?? 0;

    final sColor = _statusColor(displayStatus);
    final sBg = _statusBg(displayStatus);

    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => BillingDetailScreen(billId: b['billId'].toString(), bill: b)));
        _loadBills();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB))),
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(5)),
              child: Text(b['jobId']?.toString() ?? '-',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1D6FA4))),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(
              b['invoiceNumber']?.toString() ?? b['billId']?.toString() ?? '-',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
              overflow: TextOverflow.ellipsis,
            )),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: sBg, borderRadius: BorderRadius.circular(10)),
              child: Text(displayStatus, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: sColor)),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text(
              b['customerName']?.toString() ?? b['customerId']?.toString() ?? '-',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            )),
            Text('LKR ${netTotal.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
          ]),
          if (status == 'Partially Paid') ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: netTotal > 0 ? paidAmount / netTotal : 0,
              backgroundColor: const Color(0xFFE5E7EB),
              color: const Color(0xFF3B82F6),
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
            const SizedBox(height: 2),
            Text('Paid: LKR ${paidAmount.toStringAsFixed(2)} · Remaining: LKR ${(netTotal - paidAmount).toStringAsFixed(2)}',
                style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          ],
          const SizedBox(height: 4),
          Row(children: [
            Text(_fmtDate(b['invoiceDate']?.toString()),
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            const Spacer(),
            if (b['dueDate'] != null)
              Text('Due: ${_fmtDate(b['dueDate']?.toString())}',
                  style: TextStyle(fontSize: 11,
                      color: isOverdue ? Colors.red : Colors.grey[500])),
          ]),
        ]),
      ),
    );
  }

  String _fmtDate(String? d) => d == null ? '-' : d.split('T').first;

  Color _statusColor(String s) => switch (s) {
    'Paid' => const Color(0xFF059669),
    'Partially Paid' => const Color(0xFF3B82F6),
    'Unpaid' => const Color(0xFFD97706),
    'Overdue' => const Color(0xFFEF4444),
    _ => const Color(0xFF6B7280),
  };

  Color _statusBg(String s) => switch (s) {
    'Paid' => const Color(0xFFD1FAE5),
    'Partially Paid' => const Color(0xFFDBEAFE),
    'Unpaid' => const Color(0xFFFEF3C7),
    'Overdue' => const Color(0xFFFEE2E2),
    _ => const Color(0xFFF3F4F6),
  };
}
