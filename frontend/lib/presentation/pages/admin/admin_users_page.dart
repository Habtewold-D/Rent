import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/services/admin_users_service.dart';
import '../../viewmodels/auth_view_model.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final _service = AdminUsersService();
  final _searchCtrl = TextEditingController();
  String _role = '';
  int _page = 1;
  final int _limit = 20;
  bool _loading = true;
  String? _error;
  List<dynamic> _users = [];
  int _totalPages = 1;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = context.read<AuthViewModel>().token;
    if (token == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.getUsers(
        token,
        search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        role: _role.isEmpty ? null : _role,
        page: _page,
        limit: _limit,
      );
      final users = (data['users'] as List?) ?? [];
      final pag = (data['pagination'] as Map<String, dynamic>?);
      setState(() {
        _users = users;
        _totalPages = (pag?['totalPages'] as int?) ?? 1;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    _page = 1;
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox.expand(
        child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search name or email',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      suffixIcon: (_searchCtrl.text.isEmpty)
                          ? null
                          : IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchCtrl.clear();
                                _applyFilters();
                              },
                            ),
                    ),
                    onChanged: (_) {
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 400), () {
                        _applyFilters();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    value: _role,
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      prefixIcon: const Icon(Icons.filter_list),
                      labelText: 'Role',
                    ),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('All')),
                      DropdownMenuItem(value: 'renter', child: Text('Renter')),
                      DropdownMenuItem(value: 'landlord', child: Text('Landlord')),
                    ],
                    onChanged: (v) {
                      setState(() => _role = v ?? '');
                      _applyFilters();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : _users.isEmpty
                      ? const Center(child: Text('No users found'))
                      : ListView.separated(
                          itemCount: _users.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final u = _users[i] as Map<String, dynamic>;
                            final name = ((u['firstName'] ?? '') + ' ' + (u['lastName'] ?? '')).trim();
                            final email = (u['email'] ?? '') as String;
                            final role = (u['role'] ?? '') as String;
                            return ListTile(
                              leading: const CircleAvatar(child: Icon(Icons.person)),
                              title: Text(name.isEmpty ? 'User' : name),
                              subtitle: Text(email),
                              trailing: Chip(label: Text(role.isEmpty ? 'renter' : role)),
                            );
                          },
                        ),
        ),
        if (!_loading)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Page $_page / $_totalPages'),
                Row(
                  children: [
                    IconButton(
                      onPressed: _page > 1 ? () { setState(() => _page--); _load(); } : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    IconButton(
                      onPressed: _page < _totalPages ? () { setState(() => _page++); _load(); } : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
        ),
      ),
    );
  }
}
