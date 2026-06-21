import 'package:flutter/material.dart';
import '../api/job_service.dart';
import '../api/customer_service.dart';
import '../api/client.dart';
import '../models/job.dart';
import '../models/customer.dart';

class JobFormScreen extends StatefulWidget {
  final Job? job; // null = add, non-null = edit
  const JobFormScreen({super.key, this.job});
  @override
  State<JobFormScreen> createState() => _JobFormScreenState();
}

class _JobFormScreenState extends State<JobFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _jobService = JobService();
  final _custService = CustomerService();
  bool _saving = false;
  bool _loading = true;

  List<Customer> _customers = [];
  List<Map<String, dynamic>> _transporters = [];

  // Form fields
  String? _customerId;
  late final TextEditingController _blCtrl;
  late final TextEditingController _cusdecCtrl;
  late final TextEditingController _cusdecDateCtrl;
  late final TextEditingController _openDateCtrl;
  String? _shipmentCategory;
  late final TextEditingController _chassisCtrl;
  late final TextEditingController _exporterCtrl;
  late final TextEditingController _lcCtrl;
  late final TextEditingController _containerCtrl;
  String? _transporter;
  late final TextEditingController _deliveryDateCtrl;

  bool get _isEdit => widget.job != null;

  static const _categories = [
    'LCL',
    'FCL',
    'Air Freight',
    'BOI',
    'Vehicle - Personal',
    'Vehicle - Company',
    'TIEP',
  ];

  bool get _isVehicle =>
      _shipmentCategory == 'Vehicle - Personal' ||
      _shipmentCategory == 'Vehicle - Company';

  /// Mirrors normalizeCusdecNumber from web app:
  /// strips leading "I - " prefix then re-adds it as "I - <value>"
  String _normalizeCusdec(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return '';
    final cleaned = raw.replaceFirst(RegExp(r'^i\s*-\s*', caseSensitive: false), '').trim();
    if (cleaned.isEmpty) return '';
    return 'I - $cleaned';
  }

  @override
  void initState() {
    super.initState();
    final j = widget.job;
    _customerId = j?.customerId;
    _blCtrl = TextEditingController(text: j?.blNumber ?? '');
    _cusdecCtrl = TextEditingController(text: j?.cusdecNumber != null ? _normalizeCusdecStatic(j!.cusdecNumber!) : '');
    _cusdecDateCtrl = TextEditingController(text: _fmtDate(j?.cusdecDate));
    _openDateCtrl = TextEditingController(text: _fmtDate(j?.openDate));
    _shipmentCategory = j?.shipmentCategory;
    _chassisCtrl = TextEditingController(text: j?.chassisNumber ?? '');
    _exporterCtrl = TextEditingController(text: j?.exporter ?? '');
    _lcCtrl = TextEditingController(text: j?.lcNumber ?? '');
    _containerCtrl = TextEditingController(text: j?.containerNumber ?? '');
    _transporter = j?.transporter;
    _deliveryDateCtrl = TextEditingController(text: _fmtDate(j?.transportDeliveryDate));
    _loadData();
  }

  String _fmtDate(String? d) => d == null ? '' : d.split('T').first;

  // Static helper — needed in initState before instance methods are available
  static String _normalizeCusdecStatic(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return '';
    final cleaned = raw.replaceFirst(RegExp(r'^i\s*-\s*', caseSensitive: false), '').trim();
    return cleaned.isEmpty ? '' : 'I - $cleaned';
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _custService.getAll(),
        apiClient.get('/transporters'),
      ]);
      _customers = results[0] as List<Customer>;
      _transporters = ((results[1] as dynamic).data as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final c in [_blCtrl, _cusdecCtrl, _cusdecDateCtrl, _openDateCtrl,
        _chassisCtrl, _exporterCtrl, _lcCtrl, _containerCtrl, _deliveryDateCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: ctrl.text.isNotEmpty ? DateTime.tryParse(ctrl.text) ?? now : now,
      firstDate: DateTime(2020), lastDate: DateTime(2030),
    );
    if (picked != null) {
      ctrl.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer'), backgroundColor: Colors.red));
      return;
    }
    if (_shipmentCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a shipment category'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'customerId': _customerId,
        'blNumber': _blCtrl.text.trim(),
        'cusdecNumber': _normalizeCusdec(_cusdecCtrl.text),
        'cusdecDate': _cusdecDateCtrl.text.trim().isEmpty ? null : _cusdecDateCtrl.text.trim(),
        'openDate': _openDateCtrl.text.trim().isEmpty ? null : _openDateCtrl.text.trim(),
        'shipmentCategory': _shipmentCategory,
        'chassisNumber': _isVehicle ? _chassisCtrl.text.trim() : null,
        'exporter': _exporterCtrl.text.trim(),
        'lcNumber': _lcCtrl.text.trim(),
        'containerNumber': _isVehicle ? null : _containerCtrl.text.trim(),
        'transporter': _transporter,
        'transportDeliveryDate': _deliveryDateCtrl.text.trim().isEmpty ? null : _deliveryDateCtrl.text.trim(),
      };
      if (_isEdit) {
        await _jobService.update(widget.job!.jobId, data);
      } else {
        await _jobService.create(data);
      }
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEdit ? 'Job updated' : 'Job created'),
          backgroundColor: const Color(0xFF10B981)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Job' : 'Add Job'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                _section('Job Information', [
                  _dropdown<Customer>(
                    label: 'Customer *',
                    items: _customers,
                    value: _customers.where((c) => c.customerId == _customerId).firstOrNull,
                    itemLabel: (c) => c.name,
                    onChanged: (c) => setState(() => _customerId = c?.customerId),
                    icon: Icons.people_outline,
                  ),
                  _dropdown<String>(
                    label: 'Shipment Category *',
                    items: _categories,
                    value: _shipmentCategory,
                    itemLabel: (s) => s,
                    onChanged: (s) => setState(() {
                      _shipmentCategory = s;
                      // Clear irrelevant fields on category change
                      if (_isVehicle) { _containerCtrl.clear(); }
                      else { _chassisCtrl.clear(); }
                    }),
                    icon: Icons.category_outlined,
                  ),
                  _dateField('Open Date', _openDateCtrl),
                  _textField('BL Number', _blCtrl,
                      validator: (v) => null), // optional
                  // CUSDEC — auto-prefix I -
                  _cusdecField(),
                  _dateField('CUSDEC Date', _cusdecDateCtrl),
                  // Chassis: only for vehicle categories
                  if (_isVehicle)
                    _textField('Chassis Number', _chassisCtrl,
                        validator: (v) => null),
                  // Container: only for non-vehicle
                  if (!_isVehicle)
                    _textField('Container Number', _containerCtrl),
                  _textField('Exporter', _exporterCtrl),
                  _textField('LC Number', _lcCtrl),
                ]),
                const SizedBox(height: 12),
                _section('Transport', [
                  // Transporter dropdown
                  _dropdown<Map<String, dynamic>>(
                    label: 'Transporter',
                    items: _transporters,
                    value: _transporters.where((t) =>
                        t['transporterId']?.toString() == _transporter ||
                        t['name']?.toString() == _transporter).firstOrNull,
                    itemLabel: (t) => t['name']?.toString() ?? '',
                    onChanged: (t) => setState(() => _transporter = t?['name']?.toString()),
                    icon: Icons.local_shipping_outlined,
                  ),
                  _dateField('Delivery Date', _deliveryDateCtrl),
                ]),
                const SizedBox(height: 80),
              ]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _save,
        backgroundColor: const Color(0xFF1D6FA4),
        foregroundColor: Colors.white,
        icon: _saving
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.save_outlined),
        label: Text(_isEdit ? 'Update' : 'Save Job'),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  /// CUSDEC field: shows "I - " prefix, normalizes on change
  Widget _cusdecField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _cusdecCtrl,
        style: const TextStyle(fontSize: 14),
        decoration: const InputDecoration(
          labelText: 'CUSDEC Number',
          labelStyle: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          hintText: 'e.g. 12345',
          prefixText: 'I - ',
          prefixStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF374151)),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        onChanged: (v) {
          // Strip prefix if user types it manually, then re-normalize on save
          final cleaned = v.replaceFirst(RegExp(r'^i\s*-\s*', caseSensitive: false), '').trim();
          if (cleaned != v) {
            _cusdecCtrl.value = TextEditingValue(
              text: cleaned,
              selection: TextSelection.collapsed(offset: cleaned.length),
            );
          }
        },
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
          border: const Border.fromBorderSide(BorderSide(color: Color(0xFFE5E7EB)))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(title.toUpperCase(), style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF1D6FA4), letterSpacing: 0.8)),
        ),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        Padding(padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)),
      ]),
    );
  }

  Widget _textField(String label, TextEditingController ctrl, {String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl, validator: validator,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          isDense: true, counterText: '',
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _dateField(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl, readOnly: true,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF9CA3AF)),
          suffixIcon: ctrl.text.isNotEmpty
              ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () => setState(() => ctrl.clear()))
              : null,
          isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        onTap: () => _pickDate(ctrl),
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required List<T> items,
    required T? value,
    required String Function(T) itemLabel,
    required void Function(T?) onChanged,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          prefixIcon: icon != null ? Icon(icon, size: 18, color: const Color(0xFF9CA3AF)) : null,
          isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        hint: Text('Select', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
        items: items.map((i) => DropdownMenuItem<T>(value: i,
            child: Text(itemLabel(i), style: const TextStyle(fontSize: 14)))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}
