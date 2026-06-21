import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/job_service.dart';
import '../api/auth_service.dart';
import '../api/client.dart';
import '../models/job.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import 'job_form_screen.dart';

class JobDetailScreen extends StatefulWidget {
  final String jobId;
  const JobDetailScreen({super.key, required this.jobId});
  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> with SingleTickerProviderStateMixin {
  final _service = JobService();
  late TabController _tabCtrl;
  Job? _job;
  bool _loading = true;
  String? _error;

  // Tab data
  List<Map<String, dynamic>> _officePayItems = [];
  List<Map<String, dynamic>> _advancePayments = [];
  List<Map<String, dynamic>> _pettyCash = [];
  bool _tabLoading = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _tabCtrl.addListener(_onTabChange);
    _loadJob();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _loadJob() async {
    setState(() { _loading = true; _error = null; });
    try {
      _job = await _service.getById(widget.jobId);
      setState(() => _loading = false);
      _loadTabData(0);
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  void _onTabChange() { if (!_tabCtrl.indexIsChanging) _loadTabData(_tabCtrl.index); }

  Future<void> _loadTabData(int index) async {
    setState(() => _tabLoading = true);
    try {
      switch (index) {
        case 1: _officePayItems = await _service.getOfficePayItems(widget.jobId); break;
        case 2: _advancePayments = await _service.getAdvancePayments(widget.jobId); break;
        case 3:
          final user = context.read<AuthProvider>().user;
          _pettyCash = await _service.getPettyCashByJobForUser(widget.jobId, user?.role ?? '');
          break;
      }
    } catch (_) {}
    if (mounted) setState(() => _tabLoading = false);
  }

  String _fmtDate(String? d) => d == null ? '-' : d.split('T').first;
  String _fmtCurrency(dynamic v) => (double.tryParse(v?.toString() ?? '') ?? 0).toStringAsFixed(2);

  Color _statusColor(String s) => switch (s) {
    'Open' => const Color(0xFFF59E0B),
    'In Progress' => const Color(0xFF3B82F6),
    'Completed' => const Color(0xFF10B981),
    'Canceled' => const Color(0xFF6B7280),
    'Overdue' => const Color(0xFFEF4444),
    _ => const Color(0xFF6B7280),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(widget.jobId),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Job',
            onPressed: () async {
              final result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => JobFormScreen(job: _job)));
              if (result == true) _loadJob();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : Column(children: [
                  // Job info header
                  _buildHeader(),
                  // Tabs
                  Material(
                    color: Colors.white,
                    child: TabBar(
                      controller: _tabCtrl,
                      isScrollable: true,
                      labelColor: const Color(0xFF1D6FA4),
                      unselectedLabelColor: const Color(0xFF6B7280),
                      indicatorColor: const Color(0xFF1D6FA4),
                      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      tabs: const [
                        Tab(text: 'Details'),
                        Tab(text: 'Office Pay'),
                        Tab(text: 'Advance'),
                        Tab(text: 'Petty Cash'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(controller: _tabCtrl, children: [
                      _buildDetailsTab(),
                      _buildOfficePayTab(),
                      _buildAdvanceTab(),
                      _buildPettyCashTab(),
                    ]),
                  ),
                ]),
    );
  }

  Widget _buildHeader() {
    final j = _job!;
    final color = _statusColor(j.status);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(j.customerName ?? 'Unknown Customer',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
          const SizedBox(height: 4),
          if (j.shipmentCategory != null)
            Text(j.shipmentCategory!, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
          child: Text(j.status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ),
      ]),
    );
  }

  Widget _buildDetailsTab() {
    final j = _job!;
    final user = context.read<AuthProvider>().user;
    final canAssignUsers = ['Admin', 'Super Admin', 'Manager'].contains(user?.role);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Job info card
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
              border: const Border.fromBorderSide(BorderSide(color: Color(0xFFE5E7EB)))),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _row('Job ID', j.jobId),
            _row('Customer', j.customerName ?? j.customerId),
            _row('BL Number', j.blNumber),
            _row('CUSDEC No.', j.cusdecNumber),
            _row('CUSDEC Date', _fmtDate(j.cusdecDate)),
            _row('Open Date', _fmtDate(j.openDate)),
            _row('Category', j.shipmentCategory),
            _row('Chassis No.', j.chassisNumber),
            _row('Container No.', j.containerNumber),
            _row('Exporter', j.exporter),
            _row('LC Number', j.lcNumber),
            _row('Transporter', j.transporter),
            _row('Delivery Date', _fmtDate(j.transportDeliveryDate)),
            if (j.billTotalAmount != null) _row('Bill Total', 'LKR ${_fmtCurrency(j.billTotalAmount)}'),
            _row('Bill Paid', 'LKR ${_fmtCurrency(j.billPaidAmount)}'),
            _row('Advance Payment', 'LKR ${_fmtCurrency(j.advancePayment)}'),
          ]),
        ),
        const SizedBox(height: 12),
        // Assigned Users card
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
              border: const Border.fromBorderSide(BorderSide(color: Color(0xFFE5E7EB)))),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.people_outline, size: 16, color: Color(0xFF1D6FA4)),
              const SizedBox(width: 6),
              const Text('Assigned Users', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
              const Spacer(),
              if (canAssignUsers)
                GestureDetector(
                  onTap: _showAssignUsersSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.edit_outlined, size: 14, color: Color(0xFF1D6FA4)),
                      SizedBox(width: 4),
                      Text('Manage', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1D6FA4))),
                    ]),
                  ),
                ),
            ]),
            const SizedBox(height: 10),
            if (j.assignedUsers.isEmpty)
              Text('No users assigned', style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic))
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: j.assignedUsers.map((u) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    u.userName.isNotEmpty ? u.userName : u.userId,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF1E40AF)),
                  ),
                )).toList(),
              ),
          ]),
        ),
      ]),
    );
  }

  void _showAssignUsersSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _AssignUsersSheet(
        jobId: widget.jobId,
        currentAssignedUserIds: _job!.assignedUsers.map((u) => u.userId).toList(),
        service: _service,
        onSuccess: () {
          _loadJob();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Widget _row(String label, String? value) {
    if (value == null || value.isEmpty || value == '-') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: Color(0xFF111827)))),
      ]),
    );
  }

  // ── Office Pay Items Tab ───────────────────────────────────────────────────
  Widget _buildOfficePayTab() {
    if (_tabLoading && _officePayItems.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_officePayItems.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[300]),
        const SizedBox(height: 8),
        Text('No office pay items', style: TextStyle(color: Colors.grey[500])),
      ]));
    }
    final total = _officePayItems.fold<double>(0, (sum, i) => sum + (double.tryParse(i['actualCost']?.toString() ?? '0') ?? 0));
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: const Color(0xFFDBEAFE),
        child: Row(children: [
          const Text('Total', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1D4ED8))),
          const Spacer(),
          Text('LKR ${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1D4ED8))),
        ]),
      ),
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _officePayItems.length,
        itemBuilder: (_, i) {
          final item = _officePayItems[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),
                border: const Border.fromBorderSide(BorderSide(color: Color(0xFFE5E7EB)))),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item['description'] ?? '-', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                if (item['createdDate'] != null)
                  Text(_fmtDate(item['createdDate'].toString()), style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ])),
              Text('LKR ${_fmtCurrency(item['actualCost'])}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1D6FA4))),
            ]),
          );
        },
      )),
    ]);
  }

  // ── Advance Payments Tab ───────────────────────────────────────────────────
  Widget _buildAdvanceTab() {
    if (_tabLoading && _advancePayments.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_advancePayments.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.payments_outlined, size: 48, color: Colors.grey[300]),
        const SizedBox(height: 8),
        Text('No advance payments', style: TextStyle(color: Colors.grey[500])),
      ]));
    }
    final total = _advancePayments.fold<double>(0, (sum, i) => sum + (double.tryParse(i['amount']?.toString() ?? i['advancePayment']?.toString() ?? '0') ?? 0));
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: const Color(0xFFD1FAE5),
        child: Row(children: [
          const Text('Total Advance', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF059669))),
          const Spacer(),
          Text('LKR ${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF059669))),
        ]),
      ),
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _advancePayments.length,
        itemBuilder: (_, i) {
          final p = _advancePayments[i];
          final amount = double.tryParse(p['amount']?.toString() ?? p['advancePayment']?.toString() ?? '0') ?? 0;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),
                border: const Border.fromBorderSide(BorderSide(color: Color(0xFFE5E7EB)))),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_fmtDate(p['paymentMadeDate']?.toString() ?? p['advancePaymentDate']?.toString()),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(4)),
                    child: Text((p['paymentType'] ?? '-').toString().toUpperCase(),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                  ),
                  if (p['checkNo'] != null && p['checkNo'].toString().isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text('Cheque #${p['checkNo']}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                ]),
                if (p['notes'] != null && p['notes'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(p['notes'].toString(), style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ),
              ])),
              Text('LKR ${amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF059669))),
            ]),
          );
        },
      )),
    ]);
  }

  // ── Petty Cash Tab ─────────────────────────────────────────────────────────
  Widget _buildPettyCashTab() {
    if (_tabLoading && _pettyCash.isEmpty) return const Center(child: CircularProgressIndicator());
    final user = context.read<AuthProvider>().user;
    final canAssign = ['Admin', 'Super Admin', 'Manager'].contains(user?.role);

    if (_pettyCash.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.account_balance_wallet_outlined, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 8),
          Text('No petty cash assignments', style: TextStyle(color: Colors.grey[500])),
          if (canAssign) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: 200,
              child: ElevatedButton.icon(
                onPressed: _showAssignPettyCashSheet,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Assign Petty Cash'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ])),
      );
    }
    final totalAssigned = _pettyCash.fold<double>(0, (s, i) => s + (double.tryParse(i['assignedAmount']?.toString() ?? '0') ?? 0));
    final totalSpent = _pettyCash.fold<double>(0, (s, i) => s + (double.tryParse(i['actualSpent']?.toString() ?? '0') ?? 0));

    return Column(children: [
      // Summary header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: const Color(0xFFEDE9FE),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Assigned', style: TextStyle(fontSize: 11, color: Color(0xFF7C3AED))),
            Text('LKR ${totalAssigned.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF7C3AED))),
          ]),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('Spent', style: TextStyle(fontSize: 11, color: Color(0xFF7C3AED))),
            Text('LKR ${totalSpent.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF7C3AED))),
          ]),
        ]),
      ),
      // Assign button for managers
      if (canAssign)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showAssignPettyCashSheet,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Assign Petty Cash', style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF7C3AED),
                side: const BorderSide(color: Color(0xFF7C3AED)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ),
      // Assignments list
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pettyCash.length,
        itemBuilder: (_, i) {
          final a = _pettyCash[i];
          return _PettyCashAssignmentCard(
            assignment: a,
            service: _service,
            currentUserId: user?.userId,
            currentUserRole: user?.role,
            fmtDate: _fmtDate,
            onSettled: () => _loadTabData(3),
          );
        },
      )),
    ]);
  }

  void _showAssignPettyCashSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _AssignPettyCashSheet(
        jobId: widget.jobId,
        service: _service,
        assignedUsers: _job!.assignedUsers,
        onSuccess: () {
          _loadTabData(3);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Petty Cash Assignment Card — shows assignment details, settlement items,
// and settle button for the assigned user.
// ═══════════════════════════════════════════════════════════════════════════════
class _PettyCashAssignmentCard extends StatefulWidget {
  final Map<String, dynamic> assignment;
  final JobService service;
  final String? currentUserId;
  final String? currentUserRole;
  final String Function(String?) fmtDate;
  final VoidCallback onSettled;

  const _PettyCashAssignmentCard({
    required this.assignment,
    required this.service,
    required this.currentUserId,
    required this.currentUserRole,
    required this.fmtDate,
    required this.onSettled,
  });

  @override
  State<_PettyCashAssignmentCard> createState() => _PettyCashAssignmentCardState();
}

class _PettyCashAssignmentCardState extends State<_PettyCashAssignmentCard> {
  bool _expanded = false;
  bool _loadingItems = false;
  bool _submittingAction = false;
  List<Map<String, dynamic>> _settlementItems = [];

  Map<String, dynamic> get a => widget.assignment;
  double get assigned => double.tryParse(a['assignedAmount']?.toString() ?? '0') ?? 0;
  double get spent => double.tryParse(a['actualSpent']?.toString() ?? '0') ?? 0;
  double get balance => assigned - spent;
  String get status => a['status']?.toString() ?? 'Pending';
  int? get assignmentId => a['assignmentId'] is int
      ? a['assignmentId']
      : int.tryParse(a['assignmentId']?.toString() ?? '');

  bool get _canSettle =>
      (status == 'Pending' || status == 'Assigned') &&
      widget.currentUserId != null &&
      a['assignedTo']?.toString() == widget.currentUserId;

  bool get _showBalanceAction {
    final s = status.toLowerCase();
    final isOwner = a['assignedTo']?.toString() == widget.currentUserId;
    return isOwner && (s == 'balance to be return' || s == 'over due' || s.contains('rejected'));
  }

  Future<void> _submitCashBalanceSettlement(String settlementType) async {
    final amount = balance.abs();
    setState(() => _submittingAction = true);
    try {
      await apiClient.post('/cash-balance-settlements', data: {
        'settlementType': settlementType,
        'amount': amount,
        'notes': settlementType == 'BALANCE_RETURN'
            ? 'Balance return for ${a['jobId'] ?? 'job'}'
            : 'Overdue collection for ${a['jobId'] ?? 'job'}',
        'relatedAssignments': a['_assignmentIds'] ?? [assignmentId],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Settlement request submitted'), backgroundColor: Color(0xFF059669)));
      }
      widget.onSettled();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _submittingAction = false);
    }
  }

  Color _statusColor(String s) {
    final l = s.toLowerCase();
    if (l.contains('over due') || l.contains('overdue')) return const Color(0xFFEF4444);
    if (l.contains('balance')) return const Color(0xFFF59E0B);
    if (l.contains('settled') || l.contains('collected') || l.contains('returned')) return const Color(0xFF059669);
    if (l == 'pending' || l == 'assigned') return const Color(0xFFD97706);
    if (l == 'closed') return const Color(0xFF6B7280);
    return const Color(0xFF6B7280);
  }

  Color _statusBg(String s) {
    final l = s.toLowerCase();
    if (l.contains('over due') || l.contains('overdue')) return const Color(0xFFFEE2E2);
    if (l.contains('balance')) return const Color(0xFFFEF3C7);
    if (l.contains('settled') || l.contains('collected') || l.contains('returned')) return const Color(0xFFD1FAE5);
    if (l == 'pending' || l == 'assigned') return const Color(0xFFFEF3C7);
    if (l == 'closed') return const Color(0xFFF3F4F6);
    return const Color(0xFFF3F4F6);
  }

  Future<void> _toggleExpand() async {
    if (_expanded) {
      setState(() => _expanded = false);
      return;
    }
    if (_settlementItems.isEmpty) {
      // First try to use inline settlementItems from the API response
      final inlineItems = a['settlementItems'];
      if (inlineItems != null && inlineItems is List && inlineItems.isNotEmpty) {
        _settlementItems = inlineItems.cast<Map<String, dynamic>>();
      } else if (assignmentId != null) {
        // Fetch from API
        setState(() => _loadingItems = true);
        try {
          final allIds = a['_assignmentIds'] as List?;
          if (allIds != null && allIds.length > 1) {
            final List<Map<String, dynamic>> allItems = [];
            for (final id in allIds) {
              final intId = id is int ? id : int.tryParse(id.toString());
              if (intId != null) {
                try {
                  final items = await widget.service.getSettlementItems(intId);
                  allItems.addAll(items);
                } catch (_) {}
              }
            }
            _settlementItems = allItems;
          } else {
            _settlementItems = await widget.service.getSettlementItems(assignmentId!);
          }
        } catch (_) {}
        if (mounted) setState(() => _loadingItems = false);
      }
    }
    setState(() => _expanded = true);
  }

  void _showSettleSheet() {
    final groupId = a['groupId']?.toString();
    final jobId = a['jobId']?.toString();
    final allAssignmentIds = a['_assignmentIds'] as List?;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _SettlePettyCashSheet(
        assignedAmount: assigned,
        assignmentId: assignmentId!,
        groupId: groupId,
        jobId: jobId,
        allAssignmentIds: allAssignmentIds,
        shipmentCategory: a['shipmentCategory']?.toString(),
        service: widget.service,
        onSuccess: () {
          widget.onSettled();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sColor = _statusColor(status);
    final sBg = _statusBg(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(children: [
        // Header row (tappable to expand)
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: (!_canSettle && status != 'Pending' && status != 'Assigned') ? _toggleExpand : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(
                  a['assignedToName']?.toString() ?? a['assignedByName']?.toString() ?? a['assignedTo']?.toString() ?? 'Unknown',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                )),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: sBg, borderRadius: BorderRadius.circular(10)),
                  child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: sColor)),
                ),
                if (status != 'Pending' && status != 'Assigned') ...[
                  const SizedBox(width: 4),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 18, color: Colors.grey[400]),
                ],
              ]),
              const SizedBox(height: 8),
              // Stats row
              Row(children: [
                _stat('Assigned', assigned, const Color(0xFF7C3AED)),
                const SizedBox(width: 14),
                _stat('Spent', spent, const Color(0xFF1D6FA4)),
                const SizedBox(width: 14),
                _stat('Balance', balance, balance >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
              ]),
              if (a['assignedDate'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(widget.fmtDate(a['assignedDate'].toString()),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ),
            ]),
          ),
        ),

        // Settle button (for Waff Clerk with Pending status)
        if (_canSettle)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showSettleSheet,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Settle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),

        // Return Balance / Collect Overdue buttons
        if (_showBalanceAction)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submittingAction ? null : () => _submitCashBalanceSettlement(
                  balance < 0 ? 'OVERDUE_COLLECTION' : 'BALANCE_RETURN',
                ),
                icon: Icon(
                  balance < 0 ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 18,
                ),
                label: Text(_submittingAction ? 'Submitting...' :
                  balance < 0 ? 'Collect Overdue' : 'Return Balance'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: balance < 0
                      ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),

        // Expanded settlement items
        if (_expanded) ...[
          const Divider(height: 1),
          if (_loadingItems)
            const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          else if (_settlementItems.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('No settlement items', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            )
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Settlement Items (${_settlementItems.length})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                const SizedBox(height: 8),
                ..._settlementItems.map((item) => _buildSettlementItemRow(item)),
              ]),
            ),
        ],
      ]),
    );
  }

  Widget _stat(String label, double value, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
      Text('LKR ${value.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    ]);
  }

  Widget _buildSettlementItemRow(Map<String, dynamic> item) {
    final cost = double.tryParse(item['actualCost']?.toString() ?? '0') ?? 0;
    final hasBill = item['hasBill'] == true || item['hasBill'] == 1;
    final canEdit = _canEditItems;
    final itemId = item['settlementItemId'] is int
        ? item['settlementItemId']
        : int.tryParse(item['settlementItemId']?.toString() ?? '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        if (hasBill)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(Icons.receipt_outlined, size: 14, color: Colors.green[400]),
          ),
        Expanded(child: Text(
          item['itemName']?.toString() ?? '-',
          style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
        )),
        Text('LKR ${cost.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
        if (canEdit && itemId != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _editItem(item, itemId),
            child: Icon(Icons.edit_outlined, size: 16, color: Colors.blue[400]),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _deleteItem(itemId),
            child: Icon(Icons.delete_outline, size: 16, color: Colors.red[400]),
          ),
        ],
      ]),
    );
  }

  bool get _canEditItems {
    final isOwner = a['assignedTo']?.toString() == widget.currentUserId;
    final isManagerOrClerk = ['Manager', 'Waff Clerk'].contains(widget.currentUserRole);
    final s = status.toLowerCase();
    // Only allow edit/delete for these specific statuses (matches web app behavior)
    final isEditable = s == 'settled' || 
        s == 'balance to be return' || 
        s == 'over due' ||
        s == 'settled/rejected' ||
        (s.contains('settled') && !s.contains('returned') && !s.contains('collected'));
    return isOwner && isManagerOrClerk && isEditable;
  }

  void _editItem(Map<String, dynamic> item, int itemId) {
    final nameCtrl = TextEditingController(text: item['itemName']?.toString() ?? '');
    final costCtrl = TextEditingController(text: (double.tryParse(item['actualCost']?.toString() ?? '0') ?? 0).toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Item', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Item Name', isDense: true),
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: costCtrl,
            decoration: const InputDecoration(labelText: 'Amount', isDense: true),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 14),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final newCost = double.tryParse(costCtrl.text);
              if (nameCtrl.text.trim().isEmpty || newCost == null || newCost <= 0) return;
              Navigator.pop(ctx);
              try {
                await widget.service.updateSettlementItem(assignmentId!, itemId, nameCtrl.text.trim(), newCost);
                _settlementItems = await widget.service.getSettlementItems(assignmentId!);
                widget.onSettled();
                if (mounted) setState(() {});
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(int itemId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        content: const Text('Are you sure you want to delete this item?', style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await widget.service.deleteSettlementItem(assignmentId!, itemId);
      _settlementItems = await widget.service.getSettlementItems(assignmentId!);
      widget.onSettled();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red));
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Settle Petty Cash Bottom Sheet
// ═══════════════════════════════════════════════════════════════════════════════
class _SettlePettyCashSheet extends StatefulWidget {
  final double assignedAmount;
  final int assignmentId;
  final String? groupId;
  final String? jobId;
  final List? allAssignmentIds;
  final String? shipmentCategory;
  final JobService service;
  final VoidCallback onSuccess;

  const _SettlePettyCashSheet({
    required this.assignedAmount,
    required this.assignmentId,
    this.groupId,
    this.jobId,
    this.allAssignmentIds,
    this.shipmentCategory,
    required this.service,
    required this.onSuccess,
  });

  @override
  State<_SettlePettyCashSheet> createState() => _SettlePettyCashSheetState();
}

class _SettlePettyCashSheetState extends State<_SettlePettyCashSheet> {
  List<_SettleItem> _items = [];
  List<Map<String, dynamic>> _settledItems = [];
  bool _loadingTemplates = true;
  bool _submitting = false;
  String? _error;

  double get _totalSpent => _items.fold<double>(0, (s, i) => s + (double.tryParse(i.costCtrl.text) ?? 0));
  double get _balance => widget.assignedAmount - _totalSpent;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    try {
      // 1. Load existing settlement items for THIS assignment
      List<Map<String, dynamic>> existingItems = [];
      try {
        existingItems = await widget.service.getSettlementItems(widget.assignmentId);
      } catch (_) {}

      // 2. Load read-only predefined items from OTHER assignments (same job)
      List<Map<String, dynamic>> readOnlyPredefinedItems = [];
      if (widget.jobId != null) {
        try {
          final jobAssignment = await widget.service.getJobAssignmentWithReadOnly(
            widget.jobId!, widget.assignmentId);
          if (jobAssignment != null && jobAssignment['readOnlyPredefinedItems'] != null) {
            readOnlyPredefinedItems = (jobAssignment['readOnlyPredefinedItems'] as List<dynamic>)
                .cast<Map<String, dynamic>>();
          }
        } catch (_) {}
      }

      // 3. Load templates for the shipment category
      List<Map<String, dynamic>> templates = [];
      if (widget.shipmentCategory != null && widget.shipmentCategory!.isNotEmpty) {
        try {
          templates = await widget.service.getPayItemTemplates(widget.shipmentCategory!);
        } catch (_) {}
      }

      // 4. Build items list (same logic as web app):
      if (templates.isNotEmpty) {
        for (final template in templates) {
          final templateName = template['itemName']?.toString() ?? '';

          // Check if this user already settled this item
          final ownItem = existingItems.where(
            (ei) => ei['itemName']?.toString() == templateName).firstOrNull;

          // Check if another user settled this item
          final otherItem = readOnlyPredefinedItems.where(
            (oi) => oi['itemName']?.toString() == templateName).firstOrNull;

          if (ownItem != null) {
            _settledItems.add(ownItem);
          } else if (otherItem != null) {
            _settledItems.add(otherItem);
          } else {
            final item = _SettleItem();
            item.nameCtrl.text = templateName;
            item.isTemplate = true;
            _items.add(item);
          }
        }

        // Add custom items from existing settlement as settled
        for (final ci in existingItems.where(
          (ei) => (ei['isCustomItem'] == true || ei['isCustomItem'] == 1))) {
          _settledItems.add(ci);
        }
      } else if (existingItems.isNotEmpty || readOnlyPredefinedItems.isNotEmpty) {
        // No templates - show existing items
        for (final item in existingItems) {
          final hasPaidBy = item['paidBy'] != null && item['paidBy'].toString().trim().isNotEmpty;
          if (hasPaidBy) {
            _settledItems.add(item);
          } else {
            final settleItem = _SettleItem();
            settleItem.nameCtrl.text = item['itemName']?.toString() ?? '';
            final cost = double.tryParse(item['actualCost']?.toString() ?? '0') ?? 0;
            if (cost > 0) settleItem.costCtrl.text = cost.toStringAsFixed(2);
            settleItem.hasBill = item['hasBill'] == true || item['hasBill'] == 1;
            _items.add(settleItem);
          }
        }
        for (final oi in readOnlyPredefinedItems) {
          _settledItems.add(oi);
        }
      }

      // If no items at all, start with one blank
      if (_items.isEmpty && _settledItems.isEmpty) {
        _items = [_SettleItem()];
      }
      // If only settled items exist, add one blank for the user
      if (_items.isEmpty && _settledItems.isNotEmpty) {
        _items = [_SettleItem()];
      }

      if (mounted) setState(() => _loadingTemplates = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingTemplates = false;
          if (_items.isEmpty) _items = [_SettleItem()];
        });
      }
    }
  }

  void _addItem() => setState(() => _items.add(_SettleItem()));

  void _removeItem(int index) {
    if (_items.length > 1) setState(() => _items.removeAt(index));
  }

  Future<void> _submit() async {
    final validItems = _items.where((i) =>
        i.nameCtrl.text.trim().isNotEmpty &&
        (double.tryParse(i.costCtrl.text) ?? 0) > 0).toList();

    setState(() { _submitting = true; _error = null; });
    try {
      final payload = validItems.map((i) {
        return <String, dynamic>{
          'itemName': i.nameCtrl.text.trim(),
          'actualCost': double.parse(i.costCtrl.text),
          'hasBill': i.hasBill,
          'isCustomItem': !i.isTemplate,
        };
      }).toList();

      // Use group settle if groupId available, otherwise single settle
      if (widget.groupId != null && widget.groupId!.isNotEmpty) {
        await widget.service.settleGroupPettyCash(widget.groupId!, payload);
      } else {
        await widget.service.settlePettyCash(widget.assignmentId, payload);
      }
      widget.onSuccess();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Handle
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 12),
        const Text('Settle Petty Cash', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
        const SizedBox(height: 4),
        Text('Assigned: LKR ${widget.assignedAmount.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF7C3AED), fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        
        // Settlement Items section header
        const Text('Settlement Items',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
        const SizedBox(height: 4),
        Text('Fill in only the items you used for. Tick the "Bill" checkbox if you have a proof receipt for that item. Items already paid in other assignments are shown as read-only. You can also submit without entering any amounts to return the full petty cash allocation.',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            maxLines: 5,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 12),
        
        // Items list (scrollable)
        if (_loadingTemplates)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
        else
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.35),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // All items (both settled and unsettled) mixed together like web app
                  ..._buildAllItemsWithIndices(),
                ],
              ),
            ),
          ),
        
        const SizedBox(height: 12),
        // Add item button
        if (_items.isNotEmpty || _settledItems.isEmpty)
          TextButton.icon(
            onPressed: _addItem,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Item', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF7C3AED)),
          ),
        const SizedBox(height: 12),
        
        // Summary
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Total Spent', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
              Text('LKR ${_totalSpent.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1D6FA4))),
            ]),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Balance', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
              Text('LKR ${_balance.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: _balance >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444))),
            ]),
          ]),
        ),
        
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.red)),
        ],
        
        // Submit button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _submitting
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Submit Settlement', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }

  /// Build items mixed with settled and unsettled, showing item numbers like web app
  List<Widget> _buildAllItemsWithIndices() {
    int itemNum = 1;
    
    // Build settled items first
    final settledWidgets = _settledItems.map((item) {
      final widget = _buildSettledItemCard(item, itemNum);
      itemNum++;
      return widget;
    }).toList();
    
    // Then build unsettled items
    final unsettledWidgets = _items.asMap().entries.map((entry) {
      final widget = _buildUnsettledItemCard(entry.value, itemNum);
      itemNum++;
      return widget;
    }).toList();
    
    return [...settledWidgets, ...unsettledWidgets];
  }

  /// Build card for already-settled item (read-only like web app)
  Widget _buildSettledItemCard(Map<String, dynamic> item, int itemNum) {
    final cost = double.tryParse(item['actualCost']?.toString() ?? '0') ?? 0;
    final paidByName = item['paidByName']?.toString() ?? item['paidBy']?.toString() ?? 'Unknown';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Item $itemNum',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Read-Only (Already Settled)',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFD97706))),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['itemName']?.toString() ?? '-',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF111827))),
                      const SizedBox(height: 2),
                      Text('Paid by $paidByName',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('LKR ${cost.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build card for unsettled item (editable like web app)
  Widget _buildUnsettledItemCard(_SettleItem item, int itemNum) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Item $itemNum',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
            const SizedBox(height: 8),
            // Item name
            TextField(
              controller: item.nameCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Item name',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            // Amount and bill/delete buttons row
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: item.costCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Amount',
                      hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                // Bill receipt toggle
                GestureDetector(
                  onTap: () => setState(() => item.hasBill = !item.hasBill),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: item.hasBill ? Colors.green[50] : Colors.grey[100],
                      border: Border.all(
                        color: item.hasBill ? Colors.green : Colors.grey[300] ?? Colors.grey,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.receipt_outlined,
                      size: 18,
                      color: item.hasBill ? Colors.green : Colors.grey[400],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Delete button
                if (_items.length > 1)
                  GestureDetector(
                    onTap: () => _removeItem(_items.indexOf(item)),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        border: Border.all(color: Colors.red[300] ?? Colors.red),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.red[400],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}

class _SettleItem {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController costCtrl = TextEditingController();
  bool hasBill = false;
  bool isTemplate = false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Assign Petty Cash Bottom Sheet
// ═══════════════════════════════════════════════════════════════════════════════
class _AssignPettyCashSheet extends StatefulWidget {
  final String jobId;
  final JobService service;
  final List<JobAssignedUser> assignedUsers;
  final VoidCallback onSuccess;

  const _AssignPettyCashSheet({
    required this.jobId,
    required this.service,
    required this.assignedUsers,
    required this.onSuccess,
  });

  @override
  State<_AssignPettyCashSheet> createState() => _AssignPettyCashSheetState();
}

class _AssignPettyCashSheetState extends State<_AssignPettyCashSheet> {
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  JobAssignedUser? _selectedUser;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedUser == null) {
      setState(() => _error = 'Please select a user.');
      return;
    }
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Please enter a valid amount.');
      return;
    }

    setState(() { _submitting = true; _error = null; });
    try {
      await widget.service.createPettyCashAssignment(
        jobId: widget.jobId,
        assignedTo: _selectedUser!.userId,
        assignedAmount: amount,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      widget.onSuccess();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          )),
          const SizedBox(height: 12),
          const Text('Assign Petty Cash',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
          const SizedBox(height: 4),
          Text('Job: ${widget.jobId}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF7C3AED), fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),

          // User dropdown
          const Text('Assign To', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
          const SizedBox(height: 6),
          if (widget.assignedUsers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text('No users assigned to this job. Assign users first.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic)),
            )
          else
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<JobAssignedUser>(
                  value: _selectedUser,
                  hint: const Text('Select user', style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                  style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
                  items: widget.assignedUsers.map((u) => DropdownMenuItem(
                    value: u,
                    child: Text(u.userName.isNotEmpty ? u.userName : u.userId, style: const TextStyle(fontSize: 13)),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedUser = v),
                ),
              ),
            ),
          const SizedBox(height: 14),

          // Amount field
          const Text('Amount (LKR)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
          const SizedBox(height: 6),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Enter amount',
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF7C3AED))),
            ),
          ),
          const SizedBox(height: 14),

          // Notes field
          const Text('Notes (optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
          const SizedBox(height: 6),
          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Add notes...',
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF7C3AED))),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.red)),
          ],
          const SizedBox(height: 16),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _submitting
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Assign', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Assign Users to Job Bottom Sheet
// ═══════════════════════════════════════════════════════════════════════════════
class _AssignUsersSheet extends StatefulWidget {
  final String jobId;
  final List<String> currentAssignedUserIds;
  final JobService service;
  final VoidCallback onSuccess;

  const _AssignUsersSheet({
    required this.jobId,
    required this.currentAssignedUserIds,
    required this.service,
    required this.onSuccess,
  });

  @override
  State<_AssignUsersSheet> createState() => _AssignUsersSheetState();
}

class _AssignUsersSheetState extends State<_AssignUsersSheet> {
  final _authService = AuthService();
  List<User> _users = [];
  Set<String> _selectedUserIds = {};
  bool _loadingUsers = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedUserIds = widget.currentAssignedUserIds.toSet();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await _authService.getUsers();
      setState(() {
        // Only show Managers and Waff Clerks for job assignment
        _users = users.where((u) => u.isActive && ['Manager', 'Waff Clerk'].contains(u.role)).toList();
        _loadingUsers = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load users';
        _loadingUsers = false;
      });
    }
  }

  void _toggleUser(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  Future<void> _submit() async {
    setState(() { _submitting = true; _error = null; });
    try {
      await widget.service.assignUsersToJob(widget.jobId, _selectedUserIds.toList());
      widget.onSuccess();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 12),
          const Text('Assign Users', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
          const SizedBox(height: 4),
          Text('Job: ${widget.jobId}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF1D6FA4), fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('${_selectedUserIds.length} user${_selectedUserIds.length == 1 ? '' : 's'} selected',
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 12),

          if (_loadingUsers)
            const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(strokeWidth: 2),
            ))
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _users.length,
                itemBuilder: (_, i) {
                  final u = _users[i];
                  final selected = _selectedUserIds.contains(u.userId);
                  return InkWell(
                    onTap: () => _toggleUser(u.userId),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Row(children: [
                        Container(
                          width: 22, height: 22,
                          decoration: BoxDecoration(
                            color: selected ? const Color(0xFF1D6FA4) : Colors.transparent,
                            border: Border.all(
                              color: selected ? const Color(0xFF1D6FA4) : const Color(0xFFD1D5DB),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: selected
                              ? const Icon(Icons.check, size: 14, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u.fullName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF111827))),
                            Text(u.role, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                          ],
                        )),
                      ]),
                    ),
                  );
                },
              ),
            ),

          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.red)),
          ],
          const SizedBox(height: 16),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D6FA4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _submitting
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Assignments', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
