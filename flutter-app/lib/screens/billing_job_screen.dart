import 'package:flutter/material.dart';
import '../api/billing_service.dart';
import '../api/client.dart';
import '../api/job_service.dart';
import '../models/job.dart';
import 'package:dio/dio.dart';

/// The "New Invoice" workflow:
/// 1. Select a job
/// 2. View / edit pay items (actual cost + billing amount)
/// 3. Add more items
/// 4. Generate invoice
class BillingJobScreen extends StatefulWidget {
  final VoidCallback onInvoiceGenerated;
  const BillingJobScreen({super.key, required this.onInvoiceGenerated});

  @override
  State<BillingJobScreen> createState() => _BillingJobScreenState();
}

class _BillingJobScreenState extends State<BillingJobScreen> {
  final _jobService = JobService();
  final _billingService = BillingService();

  List<Job> _jobs = [];
  bool _loadingJobs = true;
  Job? _selectedJob;
  String _jobSearch = '';

  List<_PayItem> _payItems = [];
  bool _loadingPayItems = false;
  bool _generatingInvoice = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    setState(() => _loadingJobs = true);
    try {
      final jobs = await _jobService.getAll();
      // Only show jobs that are not yet fully invoiced/paid
      setState(() {
        _jobs = jobs.where((j) =>
            j.status != 'Payment Collected' && j.status != 'Completed').toList();
        _loadingJobs = false;
      });
    } catch (_) {
      setState(() => _loadingJobs = false);
    }
  }

  Future<void> _selectJob(Job job) async {
    setState(() {
      _selectedJob = job;
      _payItems = [];
      _loadingPayItems = true;
      _message = null;
    });

    List<_PayItem> items = [];

    try {
      // 1. Load Office Pay Items
      final officeItems = await _billingService.getOfficePayItemsByJob(job.jobId);
      for (final item in officeItems) {
        items.add(_PayItem(
          name: item['description']?.toString() ?? '',
          actualCost: double.tryParse(item['actualCost']?.toString() ?? '0') ?? 0,
          billingAmount: double.tryParse(item['billingAmount']?.toString() ?? '0') ?? 0,
          source: 'Office',
          officePayItemId: item['officePayItemId']?.toString(),
        ));
      }

      // 2. Load Petty Cash Settlement Items (if settled)
      if (job.pettyCashStatus == 'Settled') {
        try {
          final r = await apiClient.get('/petty-cash-assignments/job/${job.jobId}/all');
          final assignments = (r.data as List<dynamic>).cast<Map<String, dynamic>>();
          for (final assignment in assignments) {
            final settlementItems = assignment['settlementItems'] as List?;
            if (settlementItems != null) {
              for (final si in settlementItems) {
                items.add(_PayItem(
                  name: si['itemName']?.toString() ?? '',
                  actualCost: double.tryParse(si['actualCost']?.toString() ?? '0') ?? 0,
                  billingAmount: 0, // admin fills this
                  source: 'Petty Cash',
                ));
              }
            }
          }
        } catch (_) {}
      }

      // 3. If existing job.payItems exist, use those instead
      if (job.assignedUsers.isEmpty && items.isEmpty) {
        // Load pay item templates for this category
        try {
          final templates = await _jobService.getPayItemTemplates(job.shipmentCategory ?? '');
          for (final t in templates) {
            items.add(_PayItem(
              name: t['itemName']?.toString() ?? '',
              actualCost: 0,
              billingAmount: 0,
              source: 'Template',
            ));
          }
        } catch (_) {}
      }

      // 4. Load existing saved pay items from job
      try {
        final r = await apiClient.get('/jobs/${job.jobId}');
        final jobData = r.data as Map<String, dynamic>;
        final payItems = jobData['payItems'] as List?;
        if (payItems != null && payItems.isNotEmpty) {
          items = payItems.map((i) => _PayItem(
            name: i['description']?.toString() ?? '',
            actualCost: double.tryParse(i['actualCost']?.toString() ?? i['amount']?.toString() ?? '0') ?? 0,
            billingAmount: double.tryParse(i['billingAmount']?.toString() ?? i['amount']?.toString() ?? '0') ?? 0,
            source: i['source']?.toString() ?? 'Custom',
          )).toList();
        }
      } catch (_) {}

      if (items.isEmpty) {
        items.add(_PayItem(name: '', actualCost: 0, billingAmount: 0, source: 'Custom'));
      }

      // 5. For FCL jobs, ensure a transporter cost item exists
      if (job.shipmentCategory == 'FCL') {
        const transporterDesc = 'transporter cost (from placename to placename)';
        final hasTransporter = items.any((i) => i.name.toLowerCase().startsWith('transporter cost'));
        if (!hasTransporter) {
          items.insert(0, _PayItem(
            name: transporterDesc,
            actualCost: 0,
            billingAmount: 0,
            source: 'Custom',
          ));
        }
      }
    } catch (_) {
      items.add(_PayItem(name: '', actualCost: 0, billingAmount: 0, source: 'Custom'));
    }

    setState(() {
      _payItems = items;
      _loadingPayItems = false;
    });
  }

  double get _totalActual => _payItems.fold(0, (s, i) => s + i.actualCost);
  double get _totalBilling => _payItems.fold(0, (s, i) => s + i.billingAmount);
  double get _advance => double.tryParse(_selectedJob?.advancePayment.toString() ?? '0') ?? 0;
  double get _netTotal => _totalBilling - _advance;

  Future<void> _savePayItems() async {
    if (_selectedJob == null) return;
    final valid = _payItems.where((i) => i.name.isNotEmpty && i.actualCost > 0).toList();
    if (valid.isEmpty) {
      _showMessage('Add at least one item with a name and actual cost.');
      return;
    }
    try {
      final data = valid.map((i) => <String, dynamic>{
        'description': i.name,
        'actualCost': i.actualCost,
        'billingAmount': i.billingAmount,
        'paidBy': 'Office',
        'source': i.source,
      }).toList();
      await _billingService.updateJobPayItems(_selectedJob!.jobId, data);
      _showMessage('Pay items saved.');
      // Refresh
      await _selectJob(_selectedJob!);
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _generateInvoice() async {
    if (_selectedJob == null) return;

    // Validate required job details first
    if (!_hasAllRequired) {
      final missing = _requiredFields.where((f) => f.value == null || f.value!.trim().isEmpty).map((f) => f.label).join(', ');
      _showMessage('Missing required fields: $missing. Please edit the job first.');
      return;
    }

    final valid = _payItems.where((i) => i.name.isNotEmpty && i.actualCost > 0 && i.billingAmount > 0).toList();
    if (valid.isEmpty) {
      _showMessage('All items must have a name, actual cost, and billing amount.');
      return;
    }

    setState(() { _generatingInvoice = true; _message = null; });
    try {
      // Save pay items first
      final data = valid.map((i) => <String, dynamic>{
        'description': i.name,
        'actualCost': i.actualCost,
        'billingAmount': i.billingAmount,
        'source': i.source,
      }).toList();
      await _billingService.updateJobPayItems(_selectedJob!.jobId, data);

      // Generate invoice
      final result = await _billingService.createBill({
        'jobId': _selectedJob!.jobId,
        'actualCost': _totalActual,
        'billingAmount': _totalBilling,
        'advancePayment': _advance,
        'grossTotal': _totalBilling,
        'netTotal': _netTotal,
      });

      if (result['blocked'] == true) {
        _showMessage('Invoice blocked: ${result['message']}');
        return;
      }

      _showMessage('Invoice generated successfully!');
      setState(() { _selectedJob = null; _payItems = []; });
      widget.onInvoiceGenerated();
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _generatingInvoice = false);
    }
  }

  void _showMessage(String msg) => setState(() => _message = msg);

  void _addItem() => setState(() => _payItems.add(_PayItem(name: '', actualCost: 0, billingAmount: 0, source: 'Custom')));

  void _removeItem(int i) {
    if (_payItems.length > 1) setState(() => _payItems.removeAt(i));
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedJob == null) {
      return _buildJobPicker();
    }
    return _buildPayItemsEditor();
  }

  // ── Job Picker ────────────────────────────────────────────────────────────────
  Widget _buildJobPicker() {
    final q = _jobSearch.toLowerCase();
    final filtered = _jobs.where((j) =>
      q.isEmpty ||
      j.jobId.toLowerCase().contains(q) ||
      (j.customerName?.toLowerCase().contains(q) ?? false) ||
      (j.shipmentCategory?.toLowerCase().contains(q) ?? false)
    ).toList();

    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.all(12),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Search jobs...',
            prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF9CA3AF)),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          ),
          onChanged: (v) => setState(() => _jobSearch = v),
        ),
      ),
      Expanded(
        child: _loadingJobs
            ? const Center(child: CircularProgressIndicator())
            : filtered.isEmpty
                ? Center(child: Text('No jobs available', style: TextStyle(color: Colors.grey[500])))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final job = filtered[i];
                      return GestureDetector(
                        onTap: () => _selectJob(job),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE5E7EB))),
                          child: Row(children: [
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(job.jobId, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1D6FA4))),
                              const SizedBox(height: 2),
                              Text(job.customerName ?? job.customerId, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                              Text(job.shipmentCategory ?? '-', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                            ])),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
                              child: Text(job.status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right, size: 18, color: Color(0xFF9CA3AF)),
                          ]),
                        ),
                      );
                    },
                  ),
      ),
    ]);
  }

  // ── Pay Items Editor ─────────────────────────────────────────────────────────
  Widget _buildPayItemsEditor() {
    return Column(children: [
      // Job header
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: () => setState(() { _selectedJob = null; _payItems = []; }),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_selectedJob!.jobId, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1D6FA4))),
            Text(_selectedJob!.customerName ?? _selectedJob!.customerId,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ])),
          Text(_selectedJob!.shipmentCategory ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ]),
      ),

      // Job details / required fields card
      _buildJobDetailsCard(),

      if (_message != null)
        Container(
          width: double.infinity,
          color: _message!.toLowerCase().contains('error') || _message!.toLowerCase().contains('blocked')
              ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(_message!, style: TextStyle(
            fontSize: 12,
            color: _message!.toLowerCase().contains('error') || _message!.toLowerCase().contains('blocked')
                ? const Color(0xFFEF4444) : const Color(0xFF059669),
          )),
        ),

      if (_loadingPayItems)
        const Expanded(child: Center(child: CircularProgressIndicator()))
      else
        Expanded(child: Column(children: [
          // Totals bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFEFF6FF),
            child: Row(children: [
              _totalStat('Actual', _totalActual, Colors.grey[700]!),
              const SizedBox(width: 12),
              _totalStat('Billing', _totalBilling, const Color(0xFF1D6FA4)),
              if (_advance > 0) ...[
                const SizedBox(width: 12),
                _totalStat('Advance', -_advance, Colors.orange),
              ],
              const Spacer(),
              _totalStat('Net Total', _netTotal, const Color(0xFF059669)),
            ]),
          ),

          // Pay items list
          Expanded(child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
            itemCount: _payItems.length,
            itemBuilder: (_, i) => _buildPayItemRow(i),
          )),
        ])),

      // Bottom actions
      if (!_loadingPayItems)
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(children: [
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Item', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1D6FA4),
                  side: const BorderSide(color: Color(0xFF1D6FA4)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              )),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(
                onPressed: _savePayItems,
                icon: const Icon(Icons.save_outlined, size: 16),
                label: const Text('Save Items', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey[400]!),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              )),
            ]),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generatingInvoice ? null : _generateInvoice,
                icon: _generatingInvoice
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.receipt_long_outlined, size: 18),
                label: Text(_generatingInvoice ? 'Generating...' : 'Generate Invoice'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ]),
        ),
    ]);
  }

  bool get _isVehicle =>
      _selectedJob?.shipmentCategory == 'Vehicle - Personal' ||
      _selectedJob?.shipmentCategory == 'Vehicle - Company';

  bool get _isFcl => _selectedJob?.shipmentCategory == 'FCL';

  List<_RequiredField> get _requiredFields {
    final job = _selectedJob!;
    final fields = <_RequiredField>[
      _RequiredField('BL Number', job.blNumber),
      _RequiredField('CUSDEC Number', job.cusdecNumber),
      _RequiredField('LC Number', job.lcNumber),
    ];
    if (_isVehicle) {
      fields.add(_RequiredField('Chassis Number', job.chassisNumber));
    } else {
      fields.add(_RequiredField('Container Number', job.containerNumber));
    }
    if (_isFcl) {
      fields.add(_RequiredField('Transporter', job.transporter));
      fields.add(_RequiredField('Delivery Date', job.transportDeliveryDate));
    }
    return fields;
  }

  bool get _hasAllRequired => _requiredFields.every((f) => f.value != null && f.value!.trim().isNotEmpty);

  Widget _buildJobDetailsCard() {
    final fields = _requiredFields;
    final missingCount = fields.where((f) => f.value == null || f.value!.trim().isEmpty).length;

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 1),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        initiallyExpanded: missingCount > 0,
        title: Row(children: [
          Icon(
            missingCount > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline,
            size: 18,
            color: missingCount > 0 ? Colors.orange : const Color(0xFF059669),
          ),
          const SizedBox(width: 8),
          Text('Job Details',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          if (missingCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)),
              child: Text('$missingCount missing',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFD97706))),
            ),
        ]),
        children: [
          ...fields.map((f) => _detailRow(f.label, f.value)),
          if (missingCount > 0) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  // Navigate to job edit screen
                  final result = await Navigator.of(context).pushNamed(
                    '/job-edit',
                    arguments: _selectedJob,
                  );
                  // If returned true, reload job
                  if (result == true) {
                    final jobs = await _jobService.getAll();
                    final updated = jobs.firstWhere((j) => j.jobId == _selectedJob!.jobId, orElse: () => _selectedJob!);
                    _selectJob(updated);
                  }
                },
                icon: const Icon(Icons.edit_outlined, size: 14),
                label: const Text('Edit Job Details', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(String label, String? value) {
    final isMissing = value == null || value.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(
          width: 120,
          child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
        ),
        Expanded(child: Text(
          isMissing ? 'Not set' : value!,
          style: TextStyle(
            fontSize: 12,
            color: isMissing ? const Color(0xFFEF4444) : const Color(0xFF111827),
            fontWeight: isMissing ? FontWeight.w600 : FontWeight.normal,
            fontStyle: isMissing ? FontStyle.italic : FontStyle.normal,
          ),
        )),
        if (isMissing)
          const Icon(Icons.error_outline, size: 14, color: Color(0xFFEF4444)),
      ]),
    );
  }

  Widget _buildPayItemRow(int index) {
    final item = _payItems[index];
    final isDefaultItem = item.source != 'Custom';
    final isTransporterCost = item.name.toLowerCase().startsWith('transporter cost');
    final isEditableActual = item.source == 'Custom' || (isTransporterCost && item.source == 'Custom');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (isDefaultItem)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: item.source == 'Petty Cash' ? const Color(0xFFEDE9FE) : const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(item.source, style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w600,
                  color: item.source == 'Petty Cash' ? const Color(0xFF7C3AED) : const Color(0xFF1D4ED8))),
            ),
          Expanded(child: TextFormField(
            initialValue: item.name,
            style: const TextStyle(fontSize: 13),
            readOnly: isDefaultItem,
            decoration: InputDecoration(
              hintText: 'Item description',
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE5E7EB))),
              enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE5E7EB))),
              disabledBorder: InputBorder.none,
              filled: isDefaultItem,
              fillColor: isDefaultItem ? const Color(0xFFF9FAFB) : Colors.white,
            ),
            onChanged: (v) => item.name = v,
          )),
          if (_payItems.length > 1) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => _removeItem(index),
              child: Icon(Icons.close, size: 18, color: Colors.red[300]),
            ),
          ],
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _amtField('Actual Cost', item.actualCost, (v) {
            setState(() {
              item.actualCost = double.tryParse(v) ?? 0;
            });
          }, readOnly: isDefaultItem && !isTransporterCost)),
          const SizedBox(width: 8),
          Expanded(child: _amtField('Billing Amount', item.billingAmount, (v) {
            setState(() {
              item.billingAmount = double.tryParse(v) ?? 0;
            });
          }, highlight: true)),
        ]),
      ]),
    );
  }

  Widget _amtField(String label, double value, ValueChanged<String> onChange, {bool highlight = false, bool readOnly = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w500)),
      const SizedBox(height: 3),
      TextFormField(
        initialValue: value > 0 ? value.toStringAsFixed(2) : '',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        readOnly: readOnly,
        style: TextStyle(fontSize: 13, fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
            color: highlight ? const Color(0xFF1D6FA4) : const Color(0xFF111827)),
        decoration: InputDecoration(
          hintText: '0.00',
          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: OutlineInputBorder(
              borderSide: BorderSide(color: highlight ? const Color(0xFF1D6FA4) : const Color(0xFFE5E7EB))),
          enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: highlight ? const Color(0xFF1D6FA4) : const Color(0xFFE5E7EB))),
          disabledBorder: InputBorder.none,
          filled: readOnly,
          fillColor: readOnly ? const Color(0xFFF9FAFB) : Colors.white,
          focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF1D6FA4))),
        ),
        onChanged: onChange,
      ),
    ]);
  }

  Widget _totalStat(String label, double value, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
      Text('LKR ${value.toStringAsFixed(0)}',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    ]);
  }
}

class _PayItem {
  String name;
  double actualCost;
  double billingAmount;
  String source;
  String? officePayItemId;

  _PayItem({
    required this.name,
    required this.actualCost,
    required this.billingAmount,
    required this.source,
    this.officePayItemId,
  });
}

class _RequiredField {
  final String label;
  final String? value;
  const _RequiredField(this.label, this.value);
}
