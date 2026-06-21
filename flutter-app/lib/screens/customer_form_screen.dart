import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api/customer_service.dart';
import '../api/location_service.dart';
import '../models/customer.dart';

class CustomerFormScreen extends StatefulWidget {
  final Customer? customer;
  const CustomerFormScreen({super.key, this.customer});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerService = CustomerService();
  final _locationService = LocationService();
  bool _isSaving = false;

  // ── Basic Info ──────────────────────────────────────────────────────────────
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _websiteCtrl;
  late final TextEditingController _creditCtrl;
  late bool _isActive;

  // ── Residential Address ─────────────────────────────────────────────────────
  late final TextEditingController _addrNumCtrl;
  late final TextEditingController _addrStreet1Ctrl;
  late final TextEditingController _addrStreet2Ctrl;
  late final TextEditingController _addrCountryCtrl;
  District? _addrDistrict;
  City? _addrCity;

  // ── Office Address ──────────────────────────────────────────────────────────
  late bool _sameAddress;
  late final TextEditingController _offNumCtrl;
  late final TextEditingController _offStreet1Ctrl;
  late final TextEditingController _offStreet2Ctrl;
  late final TextEditingController _offCountryCtrl;
  District? _offDistrict;
  City? _offCity;

  // ── Locations data ──────────────────────────────────────────────────────────
  List<District> _districts = [];
  List<City> _addrCities = [];
  List<City> _offCities = [];
  bool _locationsLoading = true;

  // ── Categories ──────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _allCategories = [];
  // Stores selected categoryIds (int)
  late List<int> _selectedCategoryIds;

  // ── Contact Persons ─────────────────────────────────────────────────────────
  late List<_ContactPersonEntry> _contacts;

  bool get _isEdit => widget.customer != null;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;

    _nameCtrl        = TextEditingController(text: c?.name ?? '');
    _phoneCtrl       = TextEditingController(text: c?.mainPhone ?? '');
    _emailCtrl       = TextEditingController(text: c?.email ?? '');
    _websiteCtrl     = TextEditingController(text: c?.website ?? '');
    _creditCtrl      = TextEditingController(text: c?.creditPeriodDays?.toString() ?? '30');
    _isActive        = c?.isActive ?? true;

    _addrNumCtrl     = TextEditingController(text: c?.addressNumber ?? '');
    _addrStreet1Ctrl = TextEditingController(text: c?.addressStreet1 ?? '');
    _addrStreet2Ctrl = TextEditingController(text: c?.addressStreet2 ?? '');
    _addrCountryCtrl = TextEditingController(text: c?.addressCountry ?? 'Sri Lanka');

    _sameAddress     = c?.isOfficeAddressSame ?? false;
    _offNumCtrl      = TextEditingController(text: c?.officeAddressNumber ?? '');
    _offStreet1Ctrl  = TextEditingController(text: c?.officeAddressStreet1 ?? '');
    _offStreet2Ctrl  = TextEditingController(text: c?.officeAddressStreet2 ?? '');
    _offCountryCtrl  = TextEditingController(text: c?.officeAddressCountry ?? 'Sri Lanka');

    _selectedCategoryIds = []; // will be populated after categories load

    final existing = c?.contactPersons ?? [];
    _contacts = existing.isNotEmpty
        ? existing.map((p) => _ContactPersonEntry(
              name: p.name, phone: p.phone ?? '',
              email: p.email ?? '', designation: p.designation ?? '',
            )).toList()
        : [_ContactPersonEntry()];

    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final results = await Future.wait([
        _locationService.getDistricts(),
        _customerService.getCategories(),
      ]);
      final districts = results[0] as List<District>;
      final cats = results[1] as List<Map<String, dynamic>>;

      // Match existing district/city names to objects (edit mode)
      District? addrDist, offDist;
      List<City> addrCities = [], offCities = [];

      if (widget.customer?.addressDistrict != null) {
        addrDist = districts.firstWhere(
          (d) => d.districtName == widget.customer!.addressDistrict,
          orElse: () => districts.first,
        );
        addrCities = await _locationService.getCitiesByDistrict(addrDist.districtId);
      }
      if (widget.customer?.officeAddressDistrict != null) {
        offDist = districts.firstWhere(
          (d) => d.districtName == widget.customer!.officeAddressDistrict,
          orElse: () => districts.first,
        );
        offCities = await _locationService.getCitiesByDistrict(offDist.districtId);
      }

      setState(() {
        _districts = districts;
        _allCategories = cats;
        // Match existing category names → IDs for edit mode
        if (widget.customer?.categories.isNotEmpty == true) {
          _selectedCategoryIds = cats
              .where((cat) => widget.customer!.categories
                  .contains((cat['categoryName'] ?? '').toString()))
              .map((cat) => cat['categoryId'] as int)
              .toList();
        }
        _addrDistrict = addrDist;
        _addrCities = addrCities;
        _addrCity = addrCities.isNotEmpty && widget.customer?.addressCity != null
            ? addrCities.firstWhere(
                (c) => c.cityName == widget.customer!.addressCity,
                orElse: () => addrCities.first)
            : null;
        _offDistrict = offDist;
        _offCities = offCities;
        _offCity = offCities.isNotEmpty && widget.customer?.officeAddressCity != null
            ? offCities.firstWhere(
                (c) => c.cityName == widget.customer!.officeAddressCity,
                orElse: () => offCities.first)
            : null;
        _locationsLoading = false;
      });
    } catch (_) {
      setState(() => _locationsLoading = false);
    }
  }

  Future<void> _onAddrDistrictChanged(District? d) async {
    setState(() { _addrDistrict = d; _addrCity = null; _addrCities = []; });
    if (d == null) return;
    final cities = await _locationService.getCitiesByDistrict(d.districtId);
    setState(() => _addrCities = cities);
  }

  Future<void> _onOffDistrictChanged(District? d) async {
    setState(() { _offDistrict = d; _offCity = null; _offCities = []; });
    if (d == null) return;
    final cities = await _locationService.getCitiesByDistrict(d.districtId);
    setState(() => _offCities = cities);
  }

  @override
  void dispose() {
    for (final ctrl in [
      _nameCtrl, _phoneCtrl, _emailCtrl, _websiteCtrl, _creditCtrl,
      _addrNumCtrl, _addrStreet1Ctrl, _addrStreet2Ctrl, _addrCountryCtrl,
      _offNumCtrl, _offStreet1Ctrl, _offStreet2Ctrl, _offCountryCtrl,
    ]) { ctrl.dispose(); }
    for (final c in _contacts) c.dispose();
    super.dispose();
  }

  // ── Validators ──────────────────────────────────────────────────────────────
  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;
  String? _nameValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Name is required';
    return null;
  }
  String? _phoneValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Phone is required';
    if (!RegExp(r'^\d{10}$').hasMatch(v.trim().replaceAll(' ', ''))) return 'Must be 10 digits';
    return null;
  }
  String? _emailValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim())) return 'Invalid email';
    return null;
  }
  String? _creditValidator(String? v) {
    final n = int.tryParse(v?.trim() ?? '');
    if (n == null || n < 1 || n > 365) return '1–365 days';
    return null;
  }

  // ── Save ────────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please fix the errors before saving'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    if (_addrDistrict == null || _addrCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a district and city for residential address'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    if (!_sameAddress && (_offDistrict == null || _offCity == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a district and city for office address'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    final validContacts = _contacts
        .where((c) => c.nameCtrl.text.trim().isNotEmpty && c.phoneCtrl.text.trim().isNotEmpty)
        .toList();
    if (validContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('At least one contact person with name and phone is required'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final offDistrict = _sameAddress ? _addrDistrict : _offDistrict;
      final offCity     = _sameAddress ? _addrCity     : _offCity;
      final data = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'mainPhone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'website': _websiteCtrl.text.trim(),
        'creditPeriodDays': int.parse(_creditCtrl.text.trim()),
        'isActive': _isActive,
        'addressNumber': _addrNumCtrl.text.trim(),
        'addressStreet1': _addrStreet1Ctrl.text.trim(),
        'addressStreet2': _addrStreet2Ctrl.text.trim(),
        'addressDistrict': _addrDistrict!.districtName,
        'addressCity': _addrCity!.cityName,
        'addressCountry': _addrCountryCtrl.text.trim(),
        'isOfficeAddressSame': _sameAddress,
        'officeAddressNumber': _sameAddress ? _addrNumCtrl.text.trim() : _offNumCtrl.text.trim(),
        'officeAddressStreet1': _sameAddress ? _addrStreet1Ctrl.text.trim() : _offStreet1Ctrl.text.trim(),
        'officeAddressStreet2': _sameAddress ? _addrStreet2Ctrl.text.trim() : _offStreet2Ctrl.text.trim(),
        'officeAddressDistrict': offDistrict!.districtName,
        'officeAddressCity': offCity!.cityName,
        'officeAddressCountry': _sameAddress ? _addrCountryCtrl.text.trim() : _offCountryCtrl.text.trim(),
        'categories': _selectedCategoryIds,
        'contactPersons': validContacts.map((c) => {
          'name': c.nameCtrl.text.trim(), 'phone': c.phoneCtrl.text.trim(),
          'email': c.emailCtrl.text.trim(), 'designation': c.designationCtrl.text.trim(),
        }).toList(),
      };
      if (_isEdit) {
        await _customerService.update(widget.customer!.customerId, data);
      } else {
        await _customerService.create(data);
      }
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEdit ? 'Customer updated successfully' : 'Customer created successfully'),
          backgroundColor: const Color(0xFF10B981),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Customer' : 'Add Customer'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: _locationsLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Basic Info ──────────────────────────────────────────
                  _Section(title: 'Basic Information', children: [
                    _Field(label: 'Company Name *', controller: _nameCtrl,
                        validator: _nameValidator, icon: Icons.business_outlined),
                    _Field(label: 'Phone Number *', controller: _phoneCtrl,
                        validator: _phoneValidator, icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly], maxLength: 10),
                    _Field(label: 'Email *', controller: _emailCtrl,
                        validator: _emailValidator, icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress),
                    _Field(label: 'Website', controller: _websiteCtrl,
                        icon: Icons.language_outlined, keyboardType: TextInputType.url),
                    _Field(label: 'Credit Period (days) *', controller: _creditCtrl,
                        validator: _creditValidator, icon: Icons.calendar_today_outlined,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly], maxLength: 3),
                    if (_isEdit)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [
                          const Icon(Icons.toggle_on_outlined, size: 18, color: Color(0xFF6B7280)),
                          const SizedBox(width: 8),
                          const Text('Active', style: TextStyle(fontSize: 13, color: Color(0xFF374151))),
                          const Spacer(),
                          Switch(value: _isActive, onChanged: (v) => setState(() => _isActive = v),
                              activeColor: const Color(0xFF1D6FA4)),
                        ]),
                      ),
                  ]),
                  const SizedBox(height: 12),

                  // ── Categories ──────────────────────────────────────────
                  if (_allCategories.isNotEmpty) ...[
                    _Section(title: 'Categories', children: [
                      Wrap(
                        spacing: 8, runSpacing: 6,
                        children: _allCategories.map((cat) {
                          final name = (cat['categoryName'] ?? cat['name'] ?? '').toString().trim();
                          if (name.isEmpty) return const SizedBox.shrink();
                          final id = cat['categoryId'] as int;
                          final selected = _selectedCategoryIds.contains(id);
                          return FilterChip(
                            label: Text(name, style: const TextStyle(fontSize: 12)),
                            selected: selected,
                            onSelected: (v) => setState(() => v
                                ? _selectedCategoryIds.add(id)
                                : _selectedCategoryIds.remove(id)),
                            selectedColor: const Color(0xFF1D6FA4).withOpacity(0.15),
                            checkmarkColor: const Color(0xFF1D6FA4),
                            labelStyle: TextStyle(color: selected ? const Color(0xFF1D6FA4) : const Color(0xFF374151)),
                          );
                        }).toList(),
                      ),
                    ]),
                    const SizedBox(height: 12),
                  ],

                  // ── Residential Address ─────────────────────────────────
                  _Section(title: 'Residential Address', children: [
                    Row(children: [
                      Expanded(flex: 2, child: _Field(label: 'No. *', controller: _addrNumCtrl, validator: _req)),
                      const SizedBox(width: 10),
                      Expanded(flex: 5, child: _Field(label: 'Street 1 *', controller: _addrStreet1Ctrl, validator: _req)),
                    ]),
                    _Field(label: 'Street 2', controller: _addrStreet2Ctrl),
                    _LocationDropdown(
                      label: 'District *',
                      items: _districts,
                      value: _addrDistrict,
                      itemLabel: (d) => d.districtName,
                      onChanged: _onAddrDistrictChanged,
                      hint: 'Select district',
                    ),
                    _LocationDropdown<City>(
                      label: 'City *',
                      items: _addrCities,
                      value: _addrCity,
                      itemLabel: (c) => c.cityName,
                      onChanged: (c) => setState(() => _addrCity = c),
                      hint: _addrDistrict == null ? 'Select district first' : 'Select city',
                      enabled: _addrDistrict != null && _addrCities.isNotEmpty,
                    ),
                    _Field(label: 'Country *', controller: _addrCountryCtrl, validator: _req),
                  ]),
                  const SizedBox(height: 12),

                  // ── Office Address ──────────────────────────────────────
                  _Section(title: 'Office Address', children: [
                    Row(children: [
                      Checkbox(
                        value: _sameAddress,
                        onChanged: (v) => setState(() => _sameAddress = v ?? false),
                        activeColor: const Color(0xFF1D6FA4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const Text('Same as residential address',
                          style: TextStyle(fontSize: 13, color: Color(0xFF374151))),
                    ]),
                    if (!_sameAddress) ...[
                      Row(children: [
                        Expanded(flex: 2, child: _Field(label: 'No. *', controller: _offNumCtrl, validator: _req)),
                        const SizedBox(width: 10),
                        Expanded(flex: 5, child: _Field(label: 'Street 1 *', controller: _offStreet1Ctrl, validator: _req)),
                      ]),
                      _Field(label: 'Street 2', controller: _offStreet2Ctrl),
                      _LocationDropdown(
                        label: 'District *',
                        items: _districts,
                        value: _offDistrict,
                        itemLabel: (d) => d.districtName,
                        onChanged: _onOffDistrictChanged,
                        hint: 'Select district',
                      ),
                      _LocationDropdown<City>(
                        label: 'City *',
                        items: _offCities,
                        value: _offCity,
                        itemLabel: (c) => c.cityName,
                        onChanged: (c) => setState(() => _offCity = c),
                        hint: _offDistrict == null ? 'Select district first' : 'Select city',
                        enabled: _offDistrict != null && _offCities.isNotEmpty,
                      ),
                      _Field(label: 'Country *', controller: _offCountryCtrl, validator: _req),
                    ],
                  ]),
                  const SizedBox(height: 12),

                  // ── Contact Persons ─────────────────────────────────────
                  _Section(
                    title: 'Contact Persons',
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: Color(0xFF1D6FA4)),
                      onPressed: () => setState(() => _contacts.add(_ContactPersonEntry())),
                    ),
                    children: [
                      ..._contacts.asMap().entries.map((e) => _ContactPersonCard(
                        index: e.key, entry: e.value,
                        canRemove: _contacts.length > 1,
                        onRemove: () => setState(() => _contacts.removeAt(e.key)),
                        phoneValidator: _phoneValidator,
                      )),
                    ],
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _save,
        backgroundColor: const Color(0xFF1D6FA4),
        foregroundColor: Colors.white,
        icon: _isSaving
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.save_outlined),
        label: Text(_isEdit ? 'Update' : 'Save Customer'),
      ),
    );
  }
}

// ── Location Dropdown ──────────────────────────────────────────────────────────

class _LocationDropdown<T> extends StatelessWidget {
  final String label;
  final List<T> items;
  final T? value;
  final String Function(T) itemLabel;
  final void Function(T?) onChanged;
  final String hint;
  final bool enabled;

  const _LocationDropdown({
    required this.label,
    required this.items,
    required this.value,
    required this.itemLabel,
    required this.onChanged,
    this.hint = 'Select',
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          prefixIcon: const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF9CA3AF)),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
        hint: Text(hint, style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
        items: enabled
            ? items.map((item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(itemLabel(item), style: const TextStyle(fontSize: 14)),
                )).toList()
            : [],
        onChanged: enabled ? onChanged : null,
        validator: (_) => value == null ? 'Required' : null,
      ),
    );
  }
}

// ── Shared Section Widget ──────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  const _Section({required this.title, required this.children, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: const Border.fromBorderSide(BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(title.toUpperCase(), style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800,
                  color: Color(0xFF1D6FA4), letterSpacing: 0.8,
                )),
                if (trailing != null) ...[const Spacer(), trailing!],
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ],
      ),
    );
  }
}

// ── Text Field Widget ──────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final IconData? icon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;

  const _Field({
    required this.label, required this.controller,
    this.validator, this.icon, this.keyboardType,
    this.inputFormatters, this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller, validator: validator,
        keyboardType: keyboardType, inputFormatters: inputFormatters,
        maxLength: maxLength, style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          prefixIcon: icon != null ? Icon(icon, size: 18, color: const Color(0xFF9CA3AF)) : null,
          counterText: '', isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }
}

// ── Contact Person Card ────────────────────────────────────────────────────────

class _ContactPersonCard extends StatelessWidget {
  final int index;
  final _ContactPersonEntry entry;
  final bool canRemove;
  final VoidCallback onRemove;
  final String? Function(String?)? phoneValidator;

  const _ContactPersonCard({
    required this.index, required this.entry,
    required this.canRemove, required this.onRemove, this.phoneValidator,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8),
        border: const Border.fromBorderSide(BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Contact ${index + 1}', style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF374151))),
          const Spacer(),
          if (canRemove) GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
          ),
        ]),
        const SizedBox(height: 8),
        _Field(label: 'Name *', controller: entry.nameCtrl, icon: Icons.person_outline,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
        _Field(label: 'Phone *', controller: entry.phoneCtrl, icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 10, validator: phoneValidator),
        _Field(label: 'Email', controller: entry.emailCtrl,
            icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
        _Field(label: 'Designation', controller: entry.designationCtrl, icon: Icons.badge_outlined),
      ]),
    );
  }
}

// ── Contact Person Entry ───────────────────────────────────────────────────────

class _ContactPersonEntry {
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController designationCtrl;

  _ContactPersonEntry({String name='', String phone='', String email='', String designation=''})
      : nameCtrl = TextEditingController(text: name),
        phoneCtrl = TextEditingController(text: phone),
        emailCtrl = TextEditingController(text: email),
        designationCtrl = TextEditingController(text: designation);

  void dispose() {
    nameCtrl.dispose(); phoneCtrl.dispose();
    emailCtrl.dispose(); designationCtrl.dispose();
  }
}
