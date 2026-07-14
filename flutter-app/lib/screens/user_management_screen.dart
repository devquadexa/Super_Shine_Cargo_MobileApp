import 'package:flutter/material.dart';
import '../api/auth_service.dart';
import '../models/user.dart';

const List<String> _roles = [
  'Waff Clerk',
  'Office Executive',
  'Manager',
  'Admin',
  'Super Admin',
];

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});
  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _authService = AuthService();
  List<User> _users = [];
  bool _loading = true;
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final users = await _authService.getUsers();
      setState(() { _users = users; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  List<User> get _filteredUsers {
    if (_searchTerm.isEmpty) return _users;
    final q = _searchTerm.toLowerCase();
    return _users.where((u) =>
        u.username.toLowerCase().contains(q) ||
        u.fullName.toLowerCase().contains(q) ||
        (u.email ?? '').toLowerCase().contains(q)).toList();
  }

  Color _roleColor(String role) {
    return switch (role) {
      'Super Admin' => const Color(0xFF7C3AED),
      'Admin' => const Color(0xFF1D6FA4),
      'Manager' => const Color(0xFF059669),
      'Office Executive' => const Color(0xFFD97706),
      _ => const Color(0xFF6B7280),
    };
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredUsers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadUsers),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1D6FA4),
        onPressed: _showCreateUserForm,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
      body: Column(children: [
        // Search bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: TextField(
            onChanged: (v) => setState(() => _searchTerm = v),
            decoration: InputDecoration(
              hintText: 'Search by name, username, or email...',
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
          ),
        ),
        // User list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadUsers,
                  child: filtered.isEmpty
                      ? ListView(children: [
                          const SizedBox(height: 100),
                          Center(child: Column(children: [
                            Icon(Icons.people_outline, size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 8),
                            Text(_searchTerm.isEmpty ? 'No users found' : 'No matching users',
                                style: TextStyle(color: Colors.grey[500])),
                          ])),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _buildUserCard(filtered[i]),
                        ),
                ),
        ),
      ]),
    );
  }

  Widget _buildUserCard(User u) {
    final color = _roleColor(u.role);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        // Avatar
        CircleAvatar(
          radius: 20,
          backgroundColor: color.withValues(alpha: 0.1),
          child: Text(
            u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : '?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color),
          ),
        ),
        const SizedBox(width: 12),
        // Info
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(u.fullName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('@${u.username}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          if (u.email != null && u.email!.isNotEmpty)
            Text(u.email!, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
        ])),
        // Role badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(u.role, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ),
      ]),
    );
  }

  // ── Create User Form ────────────────────────────────────────────────────────
  void _showCreateUserForm() {
    final formKey = GlobalKey<FormState>();
    final usernameCtrl = TextEditingController();
    final fullNameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    String role = 'Waff Clerk';
    bool submitting = false;
    bool showPassword = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.88),
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
                    const Text('Create New User',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                  ]),
                  const SizedBox(height: 16),

                  // Username
                  TextFormField(
                    controller: usernameCtrl,
                    decoration: const InputDecoration(labelText: 'Username *', isDense: true),
                    inputFormatters: [],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (v.trim().length < 3) return 'At least 3 characters';
                      if (!RegExp(r'^[a-zA-Z_-]+$').hasMatch(v)) return 'Letters, _ and - only';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Full Name
                  TextFormField(
                    controller: fullNameCtrl,
                    decoration: const InputDecoration(labelText: 'Full Name *', isDense: true),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),

                  // Email
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email *', isDense: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (!v.contains('@') || !v.contains('.')) return 'Invalid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Password
                  TextFormField(
                    controller: passwordCtrl,
                    obscureText: !showPassword,
                    decoration: InputDecoration(
                      labelText: 'Password *',
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility, size: 20),
                        onPressed: () => setModalState(() => showPassword = !showPassword),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v.length < 4) return 'At least 4 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Role
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Role *', isDense: true),
                    items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (v) => setModalState(() => role = v ?? 'Waff Clerk'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  Text('User will be required to reset password on first login.',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic)),
                  const SizedBox(height: 20),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: submitting ? null : () async {
                        if (!formKey.currentState!.validate()) return;
                        if (role.isEmpty) return;
                        setModalState(() => submitting = true);
                        try {
                          await _authService.createUser(
                            username: usernameCtrl.text.trim(),
                            password: passwordCtrl.text,
                            fullName: fullNameCtrl.text.trim(),
                            email: emailCtrl.text.trim(),
                            role: role,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          _loadUsers();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('User created successfully'),
                              backgroundColor: Color(0xFF059669)));
                          }
                        } catch (e) {
                          setModalState(() => submitting = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                              content: Text(e.toString().replaceFirst('Exception: ', '')),
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
                          : const Text('Create User', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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
