import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/customer_service.dart';
import '../models/customer.dart';
import '../providers/auth_provider.dart';
import 'customer_form_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _service = CustomerService();
  final _searchController = TextEditingController();

  List<Customer> _all = [];
  List<Customer> _filtered = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await _service.getAll();
      setState(() {
        _all = data;
        _filtered = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _onSearch() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _all.where((c) {
        return c.name.toLowerCase().contains(q) ||
            (c.mainPhone ?? '').contains(q) ||
            (c.email ?? '').toLowerCase().contains(q) ||
            (c.addressCity ?? '').toLowerCase().contains(q);
      }).toList();
    });
  }

  Future<void> _openForm({Customer? customer}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CustomerFormScreen(customer: customer),
      ),
    );
    if (result == true) _load(); // refresh on save
  }
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final canManage = ['Admin', 'Super Admin', 'Manager', 'Office Executive']
        .contains(user?.role);

    return Stack(
      children: [
        Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, phone, email, city...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                isDense: true,
              ),
            ),
          ),

          // Count bar
          if (!_isLoading && _error == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFF0F4F8),
              child: Text(
                '${_filtered.length} customer${_filtered.length == 1 ? '' : 's'}',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500),
              ),
            ),

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorView(message: _error!, onRetry: _load)
                    : _filtered.isEmpty
                        ? _EmptyView(hasSearch: _searchController.text.isNotEmpty)
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                              itemCount: _filtered.length,
                              itemBuilder: (_, i) => _CustomerCard(
                                customer: _filtered[i],
                                canManage: canManage,
                                onEdit: canManage
                                    ? () => _openForm(customer: _filtered[i])
                                    : null,
                              ),
                            ),
                          ),
          ),
        ],
      ),
        // FAB — only for users who can manage
        if (canManage)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              onPressed: () => _openForm(),
              backgroundColor: const Color(0xFF1D6FA4),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add Customer'),
            ),
          ),
      ],
    );
  }
}

// ── Customer Card ────────────────────────────────────────────────────────────

class _CustomerCard extends StatelessWidget {
  final Customer customer;
  final bool canManage;
  final VoidCallback? onEdit;

  const _CustomerCard({
    required this.customer,
    required this.canManage,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetail(context),      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: const Border.fromBorderSide(
              BorderSide(color: Color(0xFFE5E7EB))),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1D6FA4).withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFF1D6FA4).withOpacity(0.1),
                child: Text(
                  customer.initials,
                  style: const TextStyle(
                      color: Color(0xFF1D6FA4),
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            customer.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Color(0xFF111827)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Active badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: customer.isActive
                                ? const Color(0xFFD1FAE5)
                                : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            customer.isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: customer.isActive
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (customer.mainPhone != null)
                      _InfoRow(
                          icon: Icons.phone_outlined,
                          text: customer.mainPhone!),
                    if (customer.email != null)
                      _InfoRow(
                          icon: Icons.email_outlined, text: customer.email!),
                    if (customer.addressCity != null ||
                        customer.addressDistrict != null)
                      _InfoRow(
                        icon: Icons.location_on_outlined,
                        text: [
                          customer.addressCity,
                          customer.addressDistrict
                        ]
                            .where((s) => s != null && s.isNotEmpty)
                            .join(', '),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: Color(0xFF9CA3AF), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomerDetailSheet(customer: customer, onEdit: onEdit),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(icon, size: 12, color: Colors.grey[500]),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Customer Detail Bottom Sheet ─────────────────────────────────────────────

class _CustomerDetailSheet extends StatelessWidget {
  final Customer customer;
  final VoidCallback? onEdit;

  const _CustomerDetailSheet({required this.customer, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(20),
                children: [
                  // Header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor:
                            const Color(0xFF1D6FA4).withOpacity(0.1),
                        child: Text(
                          customer.initials,
                          style: const TextStyle(
                              color: Color(0xFF1D6FA4),
                              fontWeight: FontWeight.bold,
                              fontSize: 20),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer.name,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF111827)),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: customer.isActive
                                    ? const Color(0xFFD1FAE5)
                                    : const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                customer.isActive ? 'Active' : 'Inactive',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: customer.isActive
                                      ? const Color(0xFF059669)
                                      : const Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (onEdit != null)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              color: Color(0xFF1D6FA4)),
                          tooltip: 'Edit Customer',
                          onPressed: () {
                            Navigator.of(context).pop();
                            onEdit!();
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  const SizedBox(height: 16),

                  // Contact Info
                  _SectionTitle(title: 'Contact Information'),
                  _DetailRow(label: 'Phone', value: customer.mainPhone),
                  _DetailRow(label: 'Email', value: customer.email),
                  _DetailRow(label: 'Website', value: customer.website),

                  const SizedBox(height: 16),
                  _SectionTitle(title: 'Address'),
                  _DetailRow(label: 'City', value: customer.addressCity),
                  _DetailRow(
                      label: 'District', value: customer.addressDistrict),
                  _DetailRow(
                      label: 'Country', value: customer.addressCountry),

                  const SizedBox(height: 16),
                  _SectionTitle(title: 'Business Details'),
                  _DetailRow(
                      label: 'Credit Period',
                      value: customer.creditPeriodDays != null
                          ? '${customer.creditPeriodDays} days'
                          : null),
                  _DetailRow(
                      label: 'Registered',
                      value: customer.registrationDate != null
                          ? customer.registrationDate!.split('T').first
                          : null),

                  // Categories
                  if (customer.categories.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _SectionTitle(title: 'Categories'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: customer.categories
                          .map((c) => Chip(
                                label: Text(c,
                                    style: const TextStyle(fontSize: 12)),
                                backgroundColor: const Color(0xFFDBEAFE),
                                labelStyle: const TextStyle(
                                    color: Color(0xFF1D4ED8)),
                                padding: EdgeInsets.zero,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ))
                          .toList(),
                    ),
                  ],

                  // Contact Persons
                  if (customer.contactPersons.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _SectionTitle(title: 'Contact Persons'),
                    ...customer.contactPersons.map(
                      (p) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(8),
                          border: const Border.fromBorderSide(
                              BorderSide(color: Color(0xFFE5E7EB))),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            if (p.designation != null)
                              Text(p.designation!,
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[600])),
                            if (p.phone != null)
                              _InfoRow(
                                  icon: Icons.phone_outlined,
                                  text: p.phone!),
                            if (p.email != null)
                              _InfoRow(
                                  icon: Icons.email_outlined,
                                  text: p.email!),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF6B7280),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String? value;

  const _DetailRow({required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value!,
              style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty & Error ─────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final bool hasSearch;
  const _EmptyView({required this.hasSearch});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasSearch ? Icons.search_off : Icons.people_outline,
            size: 56,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 12),
          Text(
            hasSearch ? 'No customers match your search' : 'No customers yet',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
