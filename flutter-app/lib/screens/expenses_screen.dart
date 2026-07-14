import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/expense_service.dart';
import '../providers/auth_provider.dart';
import 'package:dio/dio.dart';

const List<String> _expenseCategories = [
  'Food & Beverages',
  'Utility Bills',
  'WiFi / Internet',
  'Phone Cards',
  'Office Supplies',
  'Maintenance',
  'Transportation',
  'Other',
];

const List<String> _paymentMethods = ['Cash', 'Bank Transfer', 'Cheque', 'Card'];

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _expenseService = ExpenseService();
  List<Map<String, dynamic>> _expenses = [];
  bool _loading = true;
  String _categoryFilter = '';
  String? _expandedId;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _loading = true);
    try {
      final data = await _expenseService.getAll(category: _categoryFilter);
      data.sort((a, b) {
        final da = DateTime.tryParse(a['expenseDate']?.toString() ?? '') ?? DateTime(2000);
        final db = DateTime.tryParse(b['expenseDate']?.toString() ?? '') ?? DateTime(2000);
        return db.compareTo(da);
      });
      setState(() { _expenses = data; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  String _fmtDate(String? d) => d == null ? '-' : d.split('T').first;
  String _fmtCurrency(dynamic v) =>
      'LKR ${(double.tryParse(v?.toString() ?? '') ?? 0).toStringAsFixed(2)}';

  bool get _canCreate {
    final role = context.read<AuthProvider>().user?.role ?? '';
    return ['Admin', 'Super Admin', 'Manager', 'Staff'].contains(role);
  }

  bool get _canEditDelete {
    final role = context.read<AuthProvider>().user?.role ?? '';
    return ['Admin', 'Super Admin'].contains(role);
  }

  @override
  Widget build(BuildContext context) {
    final total = _expenses.fold<double>(
        0, (sum, e) => sum + (double.tryParse(e['amount']?.toString() ?? '0') ?? 0));

    return Column(children: [
      // Filter bar
      _buildFilterBar(),
      // Content
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadExpenses,
                child: _expenses.isEmpty
                    ? ListView(children: [
                        const SizedBox(height: 100),
                        Center(child: Column(children: [
                          Icon(Icons.receipt_outlined, size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 8),
                          Text('No expenses found', style: TextStyle(color: Colors.grey[500])),
                        ])),
                      ])
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                        itemCount: _expenses.length + 1,
                        itemBuilder: (_, i) {
                          if (i == 0) return _buildTotalCard(total);
                          return _buildExpenseCard(_expenses[i - 1]);
                        },
                      ),
              ),
      ),
    ]);
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _categoryFilter.isEmpty ? null : _categoryFilter,
              hint: const Text('All Categories', style: TextStyle(fontSize: 13)),
              isDense: true,
              isExpanded: true,
              style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
              items: [
                const DropdownMenuItem(value: '', child: Text('All Categories')),
                ..._expenseCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
              ],
              onChanged: (v) {
                setState(() => _categoryFilter = v ?? '');
                _loadExpenses();
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (_canCreate)
          IconButton(
            icon: const Icon(Icons.add_circle, color: Color(0xFF1D6FA4), size: 28),
            tooltip: 'New Expense',
            onPressed: () => _showExpenseForm(),
          ),
      ]),
    );
  }

  Widget _buildTotalCard(double total) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        const Icon(Icons.monetization_on_outlined, color: Colors.white70, size: 28),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Total Expenses', style: TextStyle(fontSize: 11, color: Colors.white70)),
          const SizedBox(height: 2),
          Text(_fmtCurrency(total),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
        ])),
        Text('${_expenses.length} records',
            style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ]),
    );
  }

  Widget _buildExpenseCard(Map<String, dynamic> e) {
    final id = e['expenseId']?.toString() ?? '';
    final isExpanded = _expandedId == id;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(children: [
        // Main row
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _expandedId = isExpanded ? null : id),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(e['category'] ?? '-',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF1D6FA4))),
                ),
                const Spacer(),
                Text(_fmtCurrency(e['amount']),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
              ]),
              const SizedBox(height: 6),
              Text(e['description']?.toString() ?? '-',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                Text(_fmtDate(e['expenseDate']?.toString()),
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                const Spacer(),
                Text(e['paymentMethod']?.toString() ?? '-',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                const SizedBox(width: 8),
                Icon(isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18, color: Colors.grey[400]),
              ]),
            ]),
          ),
        ),
        // Expanded details
        if (isExpanded) _buildExpandedDetails(e),
      ]),
    );
  }

  Widget _buildExpandedDetails(Map<String, dynamic> e) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Divider(height: 1),
        const SizedBox(height: 10),
        _detailRow('Expense ID', e['expenseId']?.toString() ?? '-'),
        _detailRow('Payment Method', e['paymentMethod']?.toString() ?? '-'),
        if (e['referenceNumber'] != null && e['referenceNumber'].toString().isNotEmpty)
          _detailRow('Reference #', e['referenceNumber'].toString()),
        _detailRow('Recorded By', e['recordedByName']?.toString() ?? '-'),
        if (e['notes'] != null && e['notes'].toString().isNotEmpty)
          _detailRow('Notes', e['notes'].toString()),
        if (_canEditDelete) ...[
          const SizedBox(height: 10),
          Row(children: [
            _actionBtn('Edit', const Color(0xFF1D6FA4), () => _showExpenseForm(expense: e)),
            const SizedBox(width: 8),
            _actionBtn('Delete', Colors.red, () => _confirmDelete(e['expenseId']?.toString() ?? '')),
          ]),
        ],
      ]),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 110, child: Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: Color(0xFF374151)))),
      ]),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ),
    );
  }

  Future<void> _confirmDelete(String expenseId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense', style: TextStyle(fontSize: 15)),
        content: const Text('Are you sure you want to delete this expense?'),
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
      await _expenseService.delete(expenseId);
      _loadExpenses();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense deleted'), backgroundColor: Color(0xFF059669)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is DioException ? (e.response?.data?['message'] ?? 'Failed') : 'Failed'),
          backgroundColor: Colors.red));
      }
    }
  }

  // ── Create / Edit Form ──────────────────────────────────────────────────────
  void _showExpenseForm({Map<String, dynamic>? expense}) {
    final isEdit = expense != null;
    final formKey = GlobalKey<FormState>();
    String category = expense?['category']?.toString() ?? '';
    final descCtrl = TextEditingController(text: expense?['description']?.toString() ?? '');
    final amountCtrl = TextEditingController(
        text: expense != null ? (double.tryParse(expense['amount']?.toString() ?? '') ?? 0).toString() : '');
    final dateCtrl = TextEditingController(
        text: expense?['expenseDate'] != null
            ? expense!['expenseDate'].toString().split('T').first
            : DateTime.now().toIso8601String().split('T').first);
    String paymentMethod = expense?['paymentMethod']?.toString() ?? '';
    final refCtrl = TextEditingController(text: expense?['referenceNumber']?.toString() ?? '');
    final notesCtrl = TextEditingController(text: expense?['notes']?.toString() ?? '');
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
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
                  Row(children: [
                    Text(isEdit ? 'Edit Expense' : 'New Expense',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                  ]),
                  const SizedBox(height: 14),

                  // Category
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Category *', isDense: true),
                    items: _expenseCategories.map((c) =>
                        DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setModalState(() => category = v ?? ''),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),

                  // Description
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Description *', isDense: true),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),

                  // Amount
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount (LKR) *', prefixText: 'LKR ', isDense: true),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      final n = double.tryParse(v);
                      if (n == null || n <= 0) return 'Enter valid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Date
                  TextFormField(
                    controller: dateCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Expense Date *',
                      suffixIcon: Icon(Icons.calendar_today, size: 18),
                      isDense: true,
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.tryParse(dateCtrl.text) ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (picked != null) {
                        setModalState(() => dateCtrl.text = picked.toIso8601String().split('T').first);
                      }
                    },
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),

                  // Payment Method
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Payment Method', isDense: true),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Select Method')),
                      ..._paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))),
                    ],
                    onChanged: (v) => setModalState(() => paymentMethod = v ?? ''),
                  ),
                  const SizedBox(height: 12),

                  // Reference Number
                  TextFormField(
                    controller: refCtrl,
                    decoration: const InputDecoration(labelText: 'Reference Number', isDense: true),
                  ),
                  const SizedBox(height: 12),

                  // Notes
                  TextFormField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Notes (optional)', isDense: true),
                  ),
                  const SizedBox(height: 20),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: submitting ? null : () async {
                        if (!formKey.currentState!.validate()) return;
                        if (category.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Please select a category'), backgroundColor: Colors.red));
                          return;
                        }
                        setModalState(() => submitting = true);
                        try {
                          final data = {
                            'category': category,
                            'description': descCtrl.text.trim(),
                            'amount': double.parse(amountCtrl.text),
                            'expenseDate': dateCtrl.text,
                            if (paymentMethod.isNotEmpty) 'paymentMethod': paymentMethod,
                            if (refCtrl.text.trim().isNotEmpty) 'referenceNumber': refCtrl.text.trim(),
                            if (notesCtrl.text.trim().isNotEmpty) 'notes': notesCtrl.text.trim(),
                          };
                          if (isEdit) {
                            await _expenseService.update(expense['expenseId'].toString(), data);
                          } else {
                            await _expenseService.create(data);
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                          _loadExpenses();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(isEdit ? 'Expense updated' : 'Expense created'),
                              backgroundColor: const Color(0xFF059669)));
                          }
                        } catch (e) {
                          setModalState(() => submitting = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                              content: Text(e is DioException
                                  ? (e.response?.data?['message'] ?? 'Failed')
                                  : 'Failed to save'),
                              backgroundColor: Colors.red));
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D6FA4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: submitting
                          ? const SizedBox(height: 18, width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(isEdit ? 'Update Expense' : 'Create Expense',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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
}
