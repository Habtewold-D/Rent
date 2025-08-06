import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../viewmodels/profile_view_model.dart';
import '../../../core/constants/theme_constants.dart';
import '../../../data/services/profile_service.dart';

class LandlordProfilePage extends StatefulWidget {
  const LandlordProfilePage({super.key});

  @override
  State<LandlordProfilePage> createState() => _LandlordProfilePageState();
}

class _LandlordProfilePageState extends State<LandlordProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _professionCtrl = TextEditingController();
  // Religion dropdown
  static const List<String> _religionOptions = [
    'orthodox', 'muslim', 'protestant', 'catholic', 'other_christian'
  ];
  String? _religion;
  // Change password
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _showChangePassword = false;

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _phoneCtrl.dispose();
    _ageCtrl.dispose();
    _professionCtrl.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  String _prettyReligion(String value) {
    switch (value) {
      case 'orthodox':
        return 'Orthodox';
      case 'muslim':
        return 'Muslim';
      case 'protestant':
        return 'Protestant';
      case 'catholic':
        return 'Catholic';
      case 'other_christian':
        return 'Other Christian';
      default:
        return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = context.select<AuthViewModel, String?>((a) => a.token);
    return ChangeNotifierProvider(
      create: (_) => ProfileViewModel(ProfileService()),
      builder: (context, _) {
        final vm = context.watch<ProfileViewModel>();
        if (token != null && vm.user == null && !vm.loading) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await vm.loadAll(token);
            final u = vm.user;
            if (u != null) {
              _firstCtrl.text = (u['firstName'] ?? '').toString();
              _lastCtrl.text = (u['lastName'] ?? '').toString();
              _phoneCtrl.text = (u['phone'] ?? '').toString();
              final ageVal = u['age'];
              _ageCtrl.text = (ageVal == null || ageVal.toString() == 'null') ? '' : ageVal.toString();
              _professionCtrl.text = (u['profession'] ?? '').toString();
              final rel = (u['religion'] ?? '').toString();
              _religion = _religionOptions.contains(rel) ? rel : null;
            }
          });
        }

        final user = vm.user ?? const {};
        final email = user['email']?.toString() ?? '';
        final role = user['role']?.toString() ?? '';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    const CircleAvatar(radius: 44, child: Icon(Icons.person, size: 44)),
                    const SizedBox(height: 12),
                    Text(
                      email.isEmpty ? '—' : email,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      children: [
                        _Chip(label: role.isEmpty ? 'Role: —' : 'Role: $role', color: Colors.blueGrey.shade100),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (vm.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(vm.error!, style: const TextStyle(color: Colors.red)),
                ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _firstCtrl,
                                decoration: const InputDecoration(labelText: 'First name', prefixIcon: Icon(Icons.badge_outlined)),
                                validator: (v) => (v == null || v.trim().length < 2) ? 'Enter at least 2 characters' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _lastCtrl,
                                decoration: const InputDecoration(labelText: 'Last name', prefixIcon: Icon(Icons.badge)),
                                validator: (v) => (v == null || v.trim().length < 2) ? 'Enter at least 2 characters' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _phoneCtrl,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined)),
                                validator: (v) {
                                  final raw = (v ?? '').trim();
                                  final s = raw.replaceAll(RegExp(r'[\s-]'), '');
                                  final re = RegExp(r'^(?:\+251|0)[79]\d{8}$');
                                  return s.isEmpty
                                      ? 'Phone required'
                                      : (!re.hasMatch(s) ? 'Use Ethiopian format: +2519XXXXXXXX or 09XXXXXXXX' : null);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _ageCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Age (18–65)', prefixIcon: Icon(Icons.cake_outlined)),
                                validator: (v) {
                                  final t = (v ?? '').trim();
                                  if (t.isEmpty) return null; // optional
                                  final n = int.tryParse(t);
                                  if (n == null) return 'Enter a valid number';
                                  if (n < 18 || n > 65) return 'Age must be 18–65';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _professionCtrl,
                          decoration: const InputDecoration(labelText: 'Profession (optional)', prefixIcon: Icon(Icons.work_outline)),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _religion,
                          decoration: const InputDecoration(labelText: 'Religion (optional)', prefixIcon: Icon(Icons.church_outlined)),
                          items: _religionOptions
                              .map((e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(_prettyReligion(e)),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _religion = v),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: vm.loading || token == null
                                ? null
                                : () async {
                                    if (!_formKey.currentState!.validate()) return;
                                    final ok = await vm.updateProfile(
                                      token,
                                      firstName: _firstCtrl.text.trim(),
                                      lastName: _lastCtrl.text.trim(),
                                      phone: _phoneCtrl.text.trim(),
                                      age: (_ageCtrl.text.trim().isEmpty) ? null : int.tryParse(_ageCtrl.text.trim()),
                                      profession: _professionCtrl.text.trim().isEmpty ? null : _professionCtrl.text.trim(),
                                      religion: _religion,
                                    );
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(ok ? 'Profile saved' : (vm.error ?? 'Failed to save')),
                                        backgroundColor: ok ? Colors.green : Colors.red,
                                      ),
                                    );
                                  },
                            icon: const Icon(Icons.save_outlined),
                            label: Text(vm.loading ? 'Saving...' : 'Save Profile'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!_showChangePassword)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: vm.loading ? null : () => setState(() => _showChangePassword = true),
                    icon: const Icon(Icons.password_outlined),
                    label: const Text('Change Password'),
                  ),
                ),
              if (_showChangePassword)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.password_outlined),
                                const SizedBox(width: 8),
                                Text('Change password', style: Theme.of(context).textTheme.titleMedium),
                              ],
                            ),
                            TextButton(
                              onPressed: () => setState(() => _showChangePassword = false),
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _currentPassCtrl,
                          obscureText: _obscureCurrent,
                          decoration: InputDecoration(
                            labelText: 'Current password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                              icon: Icon(_obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            ),
                          ),
                          validator: (v) => (v == null || v.isEmpty) ? 'Enter current password' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _newPassCtrl,
                          obscureText: _obscureNew,
                          decoration: InputDecoration(
                            labelText: 'New password',
                            prefixIcon: const Icon(Icons.lock_reset),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscureNew = !_obscureNew),
                              icon: Icon(_obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            ),
                          ),
                          validator: (v) => (v == null || v.length < 6) ? 'Enter at least 6 characters' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirmPassCtrl,
                          obscureText: _obscureConfirm,
                          decoration: InputDecoration(
                            labelText: 'Confirm new password',
                            prefixIcon: const Icon(Icons.lock_person_outlined),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                              icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            ),
                          ),
                          validator: (v) => v != _newPassCtrl.text ? 'Passwords do not match' : null,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: vm.loading || token == null
                                ? null
                                : () async {
                                    if ((_currentPassCtrl.text.isEmpty) || (_newPassCtrl.text.isEmpty) || (_confirmPassCtrl.text != _newPassCtrl.text)) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Please fill passwords correctly')),
                                      );
                                      return;
                                    }
                                    final ok = await vm.changePassword(
                                      token,
                                      currentPassword: _currentPassCtrl.text,
                                      newPassword: _newPassCtrl.text,
                                    );
                                    if (!mounted) return;
                                    if (ok) {
                                      _currentPassCtrl.clear();
                                      _newPassCtrl.clear();
                                      _confirmPassCtrl.clear();
                                      setState(() => _showChangePassword = false);
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(ok ? 'Password changed' : (vm.error ?? 'Failed to change password')),
                                        backgroundColor: ok ? Colors.green : Colors.red,
                                      ),
                                    );
                                  },
                            icon: const Icon(Icons.save_alt_outlined),
                            label: Text(vm.loading ? 'Updating...' : 'Update Password'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
      child: Text(label),
    );
  }
}
