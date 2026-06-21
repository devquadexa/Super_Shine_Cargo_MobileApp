import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/job_service.dart';
import '../models/job.dart';
import '../providers/auth_provider.dart';
import 'job_detail_screen.dart';
import 'job_form_screen.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});
  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  final _service = JobService();
  final _searchCtrl = TextEditingController();
  List<Job> _all = [];
  List<Job> _filtered = [];
  bool _loading = true;
  String? _error;
  String _statusFilter = 'All';

  static const _statuses = ['All', 'Open', 'In Progress', 'Completed', 'Canceled'];

  @override
  void initState() { super.initState(); _load(); _searchCtrl.addListener(_filter); }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _all = await _service.getAll();
      _filter();
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _all.where((j) {
        final matchSearch = j.jobId.toLowerCase().contains(q) ||
            (j.customerName ?? '').toLowerCase().contains(q) ||
            (j.blNumber ?? '').toLowerCase().contains(q) ||
            (j.containerNumber ?? '').toLowerCase().contains(q);
        final matchStatus = _statusFilter == 'All' || j.status == _statusFilter;
        return matchSearch && matchStatus;
      }).toList();
      _loading = false;
    });
  }

  Color _statusColor(String s) => switch (s) {
    'Open' => const Color(0xFFF59E0B),
    'In Progress' => const Color(0xFF3B82F6),
    'Completed' => const Color(0xFF10B981),
    'Canceled' => const Color(0xFF6B7280),
    'Overdue' => const Color(0xFFEF4444),
    'Pending Payment' => const Color(0xFF8B5CF6),
    'Partially Paid' => const Color(0xFFf97316),
    'Payment Collected' => const Color(0xFF14B8A6),
    _ => const Color(0xFF6B7280),
  };

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final canManage = ['Admin', 'Super Admin', 'Manager', 'Office Executive'].contains(user?.role);

    return Stack(children: [
      Column(children: [
      // Search + filter
      Container(color: Colors.white, padding: const EdgeInsets.fromLTRB(16, 10, 16, 8), child: Column(children: [
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Search job ID, customer, BL, container...',
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: _searchCtrl.clear)
                : null,
            contentPadding: const EdgeInsets.symmetric(vertical: 10), isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _statuses.map((s) {
              final active = _statusFilter == s;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(s, style: TextStyle(fontSize: 11,
                      color: active ? Colors.white : const Color(0xFF374151))),
                  selected: active,
                  selectedColor: const Color(0xFF1D6FA4),
                  onSelected: (_) { setState(() => _statusFilter = s); _filter(); },
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              );
            }).toList(),
          ),
        ),
      ])),
      // Count
      if (!_loading && _error == null)
        Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('${_filtered.length} job${_filtered.length == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
        ),
      // List
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.wifi_off, color: Colors.red, size: 48),
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Retry'))
                  ]))
                : _filtered.isEmpty
                    ? Center(child: Text('No jobs found', style: TextStyle(color: Colors.grey[500])))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _JobCard(job: _filtered[i], statusColor: _statusColor, onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => JobDetailScreen(jobId: _filtered[i].jobId),
                            ));
                          }),
                        ),
                      ),
      ),
    ]),
      if (canManage)
        Positioned(
          bottom: 16, right: 16,
          child: FloatingActionButton.extended(
            onPressed: () async {
              final result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const JobFormScreen()));
              if (result == true) _load();
            },
            backgroundColor: const Color(0xFF1D6FA4),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Add Job'),
          ),
        ),
    ]);
  }
}


class _JobCard extends StatelessWidget {
  final Job job;
  final Color Function(String) statusColor;
  final VoidCallback onTap;

  const _JobCard({required this.job, required this.statusColor, required this.onTap});

  String _fmtDate(String? d) {
    if (d == null) return '-';
    return d.split('T').first;
  }

  @override
  Widget build(BuildContext context) {
    final color = statusColor(job.status);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: color, width: 4)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(job.jobId, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF111827))),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              child: Text(job.status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
            ),
          ]),
          const SizedBox(height: 6),
          if (job.customerName != null)
            Text(job.customerName!, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          const SizedBox(height: 4),
          Row(children: [
            if (job.shipmentCategory != null) ...[
              Icon(Icons.category_outlined, size: 12, color: Colors.grey[500]),
              const SizedBox(width: 3),
              Text(job.shipmentCategory!, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              const SizedBox(width: 12),
            ],
            if (job.containerNumber != null) ...[
              Icon(Icons.inventory_2_outlined, size: 12, color: Colors.grey[500]),
              const SizedBox(width: 3),
              Text(job.containerNumber!, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ],
          ]),
          if (job.openDate != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey[500]),
              const SizedBox(width: 3),
              Text('Opened: ${_fmtDate(job.openDate)}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ]),
          ],
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.chevron_right, size: 16, color: Color(0xFF9CA3AF)),
            const Spacer(),
            if (job.advancePayment > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(8)),
                child: Text('Adv: ${job.advancePayment.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w600)),
              ),
          ]),
        ]),
      ),
    );
  }
}
