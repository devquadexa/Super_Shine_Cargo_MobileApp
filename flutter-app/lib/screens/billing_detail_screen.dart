import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'package:printing/printing.dart';
import '../api/billing_service.dart';
import '../providers/auth_provider.dart';

class BillingDetailScreen extends StatefulWidget {
  final String billId;
  final Map<String, dynamic> bill; // initial data for fast render

  const BillingDetailScreen({super.key, required this.billId, required this.bill});

  @override
  State<BillingDetailScreen> createState() => _BillingDetailScreenState();
}

class _BillingDetailScreenState extends State<BillingDetailScreen>
    with SingleTickerProviderStateMixin {
  final _service = BillingService();
  late TabController _tabCtrl;
  Map<String, dynamic> _bill = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _bill = widget.bill;
    _tabCtrl = TabController(length: 1, vsync: this);
    _loadBill();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _downloadPDF() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Generating PDF...'), duration: Duration(seconds: 2)));
      
      final pdfBytes = await _service.getBillPDF(widget.billId);
      
      if (!mounted) return;
      
      final invoiceNo = _bill['invoiceNumber']?.toString() ?? widget.billId;
      
      // Share the PDF — opens the system share sheet where user can
      // open in browser, PDF viewer, save to files, or share
      await Printing.sharePdf(
        bytes: Uint8List.fromList(pdfBytes),
        filename: 'Invoice-$invoiceNo.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ));
      }
    }
  }

  Future<void> _loadBill() async {
    setState(() => _loading = true);
    try {
      final b = await _service.getBillById(widget.billId);
      setState(() {
        _bill = b;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  String _fmtDate(String? d) => d == null ? '-' : d.split('T').first;
  String _fmtCurrency(dynamic v) => 'LKR ${(double.tryParse(v?.toString() ?? '') ?? 0).toStringAsFixed(2)}';

  Color _statusColor(String s) => switch (s) {
    'Paid' => const Color(0xFF059669),
    'Partially Paid' => const Color(0xFF3B82F6),
    'Unpaid' => const Color(0xFFD97706),
    'Overdue' => const Color(0xFFEF4444),
    _ => const Color(0xFF6B7280),
  };

  bool get _canManage => ['Admin', 'Super Admin', 'Manager']
      .contains(context.read<AuthProvider>().user?.role);

  @override
  Widget build(BuildContext context) {
    final status = _bill['paymentStatus']?.toString() ?? 'Unpaid';
    final invoiceNo = _bill['invoiceNumber']?.toString() ?? _bill['billId']?.toString() ?? '-';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(invoiceNo),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print / Download PDF',
            onPressed: !_loading ? _downloadPDF : null,
          ),
          if (_canManage && !_loading && status != 'Paid')
            IconButton(
              icon: const Icon(Icons.payment_outlined),
              tooltip: 'Record Payment',
              onPressed: _showPaymentSheet,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(children: [
                // Invoice header
                _buildHeader(status),
                // Invoice content
                _buildInvoiceContent(status),
              ]),
            ),
    );
  }

  Widget _buildHeader(String status) {
    final netTotal = double.tryParse(_bill['netTotal']?.toString() ?? '0') ?? 0;
    final paidAmount = double.tryParse(_bill['paidAmount']?.toString() ?? '0') ?? 0;
    final remaining = netTotal - paidAmount;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_bill['customerName']?.toString() ?? _bill['customerId']?.toString() ?? '-',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(_bill['jobId']?.toString() ?? '-',
                style: const TextStyle(fontSize: 12, color: Color(0xFF1D6FA4), fontWeight: FontWeight.w600)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _statusColor(status).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14)),
            child: Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _statusColor(status))),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _headerStat('Invoice Total', netTotal, const Color(0xFF111827)),
          const SizedBox(width: 16),
          _headerStat('Paid', paidAmount, const Color(0xFF059669)),
          const SizedBox(width: 16),
          _headerStat('Remaining', remaining, remaining > 0 ? const Color(0xFFEF4444) : const Color(0xFF059669)),
        ]),
      ]),
    );
  }

  Widget _headerStat(String label, double value, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        const SizedBox(height: 2),
        Text('LKR ${value.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ]),
    ));
  }

  // ── Invoice Content ────────────────────────────────────────────────────────
  Widget _buildInvoiceContent(String status) {
    final advance = double.tryParse(_bill['advancePayment']?.toString() ?? '0') ?? 0;
    final gross = double.tryParse(_bill['grossTotal']?.toString() ?? _bill['billingAmount']?.toString() ?? '0') ?? 0;
    final net = double.tryParse(_bill['netTotal']?.toString() ?? '0') ?? 0;
    final paid = double.tryParse(_bill['paidAmount']?.toString() ?? '0') ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Details card
        _infoCard('Invoice Details', [
          _row('Invoice No.', _bill['invoiceNumber']?.toString() ?? '-'),
          _row('Invoice Date', _fmtDate(_bill['invoiceDate']?.toString())),
          _row('Due Date', _fmtDate(_bill['dueDate']?.toString())),
          _row('Job', _bill['jobId']?.toString()),
          _row('Customer', _bill['customerName']?.toString() ?? _bill['customerId']?.toString()),
        ]),
        const SizedBox(height: 12),
        // Financial summary card
        _infoCard('Financial Summary', [
          _row('Gross Total', _fmtCurrency(gross)),
          if (advance > 0) _row('Advance Deduction', '- LKR ${advance.toStringAsFixed(2)}'),
          _dividerRow(),
          _row('Net Total', _fmtCurrency(net), bold: true),
          _row('Paid', _fmtCurrency(paid), color: const Color(0xFF059669)),
          _row('Remaining', _fmtCurrency(net - paid),
              color: (net - paid) > 0 ? const Color(0xFFEF4444) : const Color(0xFF059669)),
        ]),
        const SizedBox(height: 12),
        // Payment info (if paid)
        if (status == 'Paid' || status == 'Partially Paid') ...[
          _infoCard('Payment Info', [
            _row('Method', _bill['paymentMethod']?.toString()),
            if (_bill['paidDate'] != null) _row('Paid Date', _fmtDate(_bill['paidDate']?.toString())),
            if (_bill['chequeNumber'] != null) _row('Cheque No.', _bill['chequeNumber']?.toString()),
            if (_bill['bankName'] != null) _row('Bank', _bill['bankName']?.toString()),
          ]),
          const SizedBox(height: 12),
        ],
        // Action buttons
        if (_canManage && status != 'Paid') ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showPaymentSheet,
              icon: const Icon(Icons.payment_outlined, size: 18),
              label: Text(status == 'Unpaid' ? 'Record Payment' : 'Add Payment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D6FA4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _infoCard(String title, List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(title.toUpperCase(),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                  color: Color(0xFF1D6FA4), letterSpacing: 0.8)),
        ),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        Padding(padding: const EdgeInsets.all(16), child: Column(children: rows)),
      ]),
    );
  }

  Widget _row(String label, String? value, {bool bold = false, Color? color}) {
    if (value == null || value.isEmpty || value == '-') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120, child: Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500))),
        Expanded(child: Text(value, style: TextStyle(
            fontSize: 12, color: color ?? const Color(0xFF111827),
            fontWeight: bold ? FontWeight.w700 : FontWeight.normal))),
      ]),
    );
  }

  Widget _dividerRow() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Divider(height: 1, color: Color(0xFFE5E7EB)),
    );
  }

  // ── Payment Sheet ────────────────────────────────────────────────────────────
  void _showPaymentSheet() {
    final netTotal = double.tryParse(_bill['netTotal']?.toString() ?? '0') ?? 0;
    final paid = double.tryParse(_bill['paidAmount']?.toString() ?? '0') ?? 0;
    final remaining = netTotal - paid;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _PaymentSheet(
        billId: widget.billId,
        remainingAmount: remaining,
        netTotal: netTotal,
        service: _service,
        onSuccess: () { _loadBill(); Navigator.of(context).pop(); },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Payment Sheet
// ═══════════════════════════════════════════════════════════════════════════════
class _PaymentSheet extends StatefulWidget {
  final String billId;
  final double remainingAmount;
  final double netTotal;
  final BillingService service;
  final VoidCallback onSuccess;

  const _PaymentSheet({
    required this.billId,
    required this.remainingAmount,
    required this.netTotal,
    required this.service,
    required this.onSuccess,
  });

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  final _amountCtrl = TextEditingController();
  final _chequeNoCtrl = TextEditingController();
  final _chequeDateCtrl = TextEditingController();
  final _chequeAmtCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();

  String _paymentMethod = 'Cash';
  bool _isPartial = false;
  bool _submitting = false;
  String? _error;

  static const _methods = ['Cash', 'Cheque', 'Bank Transfer'];

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = widget.remainingAmount.toStringAsFixed(2);
    _dateCtrl.text = DateTime.now().toIso8601String().split('T').first;
    _isPartial = false;
  }

  @override
  void dispose() {
    for (final c in [_amountCtrl, _chequeNoCtrl, _chequeDateCtrl, _chequeAmtCtrl, _bankCtrl, _dateCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount.'); return;
    }
    if (_paymentMethod == 'Cheque' &&
        (_chequeNoCtrl.text.isEmpty || _chequeDateCtrl.text.isEmpty || _chequeAmtCtrl.text.isEmpty)) {
      setState(() => _error = 'Cheque number, date, and amount are required.'); return;
    }
    if (_paymentMethod == 'Bank Transfer' && _bankCtrl.text.isEmpty) {
      setState(() => _error = 'Bank name is required.'); return;
    }

    setState(() { _submitting = true; _error = null; });
    try {
      final details = {
        'paymentMethod': _paymentMethod,
        'paidDate': _dateCtrl.text,
        if (_paymentMethod == 'Cheque') ...{
          'chequeNumber': _chequeNoCtrl.text,
          'chequeDate': _chequeDateCtrl.text,
          'chequeAmount': double.tryParse(_chequeAmtCtrl.text),
        },
        if (_paymentMethod == 'Bank Transfer') 'bankName': _bankCtrl.text,
      };

      if (_isPartial) {
        await widget.service.applyPartialPayment(widget.billId, amount, details);
      } else {
        await widget.service.markAsPaid(widget.billId, details);
      }
      widget.onSuccess();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      ctrl.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 12),
        const Text('Record Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Remaining: LKR ${widget.remainingAmount.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF1D6FA4), fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),

        // Partial toggle
        Row(children: [
          Switch(
            value: _isPartial,
            onChanged: (v) => setState(() {
              _isPartial = v;
              if (!v) _amountCtrl.text = widget.remainingAmount.toStringAsFixed(2);
            }),
            activeColor: const Color(0xFF1D6FA4),
          ),
          const SizedBox(width: 8),
          const Text('Partial Payment', style: TextStyle(fontSize: 13)),
        ]),
        const SizedBox(height: 10),

        // Amount field
        _field('Amount (LKR)', _amountCtrl,
            type: TextInputType.number, readOnly: !_isPartial),
        const SizedBox(height: 10),

        // Payment method
        const Text('Payment Method', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _paymentMethod,
              isExpanded: true,
              items: _methods.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => setState(() => _paymentMethod = v!),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Date
        _dateFld('Payment Date', _dateCtrl),
        const SizedBox(height: 10),

        // Cheque fields
        if (_paymentMethod == 'Cheque') ...[
          _field('Cheque Number', _chequeNoCtrl),
          const SizedBox(height: 8),
          _dateFld('Cheque Date', _chequeDateCtrl),
          const SizedBox(height: 8),
          _field('Cheque Amount', _chequeAmtCtrl, type: TextInputType.number),
          const SizedBox(height: 8),
        ],

        // Bank Transfer
        if (_paymentMethod == 'Bank Transfer') ...[
          _field('Bank Name', _bankCtrl),
          const SizedBox(height: 8),
        ],

        if (_error != null) ...[
          const SizedBox(height: 4),
          Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.red)),
        ],
        const SizedBox(height: 16),

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
                : Text(_isPartial ? 'Apply Partial Payment' : 'Mark as Paid',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType type = TextInputType.text, bool readOnly = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        keyboardType: type,
        readOnly: readOnly,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF1D6FA4))),
        ),
      ),
    ]);
  }

  Widget _dateFld(String label, TextEditingController ctrl) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        readOnly: true,
        style: const TextStyle(fontSize: 14),
        onTap: () => _pickDate(ctrl),
        decoration: InputDecoration(
          isDense: true,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF9CA3AF)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF1D6FA4))),
        ),
      ),
    ]);
  }
}
