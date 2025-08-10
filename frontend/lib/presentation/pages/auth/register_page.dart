import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/validators.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../../core/constants/theme_constants.dart';
import './login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _gender; // user must choose male/female
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.darkCyan, AppColors.cyanAccent],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.person_add_alt_1_rounded, size: 56, color: AppColors.darkCyan),
                      const SizedBox(height: 12),
                      Text('Create account', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Join and find your perfect roommates', style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 24),
                      if (auth.error != null && auth.error!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: MaterialBanner(
                            backgroundColor: Colors.red.withOpacity(0.1),
                            content: Text(auth.error!, style: const TextStyle(color: Colors.red)),
                            actions: [
                              TextButton(
                                onPressed: () => context.read<AuthViewModel>().logout(),
                                child: const Text('Dismiss'),
                              )
                            ],
                          ),
                        ),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _firstCtrl,
                              decoration: const InputDecoration(labelText: 'First name', prefixIcon: Icon(Icons.badge_outlined)),
                              validator: (v) => Validators.nonEmpty(v, 'First name'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _lastCtrl,
                              decoration: const InputDecoration(labelText: 'Last name', prefixIcon: Icon(Icons.badge_outlined)),
                              validator: (v) => Validators.nonEmpty(v, 'Last name'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _emailCtrl,
                              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                              validator: Validators.email,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Phone',
                                hintText: '+2519XXXXXXXX or 09XXXXXXXX',
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                              validator: (v) {
                                final raw = (v ?? '').trim();
                                final s = raw.replaceAll(RegExp(r'[\s-]'), '');
                                final re = RegExp(r'^(?:\+251|0)[79]\d{8}$');
                                return s.isEmpty
                                    ? 'Phone required'
                                    : (!re.hasMatch(s) ? 'Use Ethiopian format: +2519XXXXXXXX or 09XXXXXXXX' : null);
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _gender,
                              decoration: const InputDecoration(labelText: 'Gender', prefixIcon: Icon(Icons.wc_outlined)),
                              hint: const Text('Select gender'),
                              items: const [
                                DropdownMenuItem(value: 'male', child: Text('Male')),
                                DropdownMenuItem(value: 'female', child: Text('Female')),
                              ],
                              onChanged: (v) => setState(() => _gender = v),
                              validator: (v) => v == null || v.isEmpty ? 'Please select gender' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passwordCtrl,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                                  icon: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                ),
                              ),
                              validator: Validators.password,
                              obscureText: _obscurePass,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _confirmCtrl,
                              decoration: InputDecoration(
                                labelText: 'Confirm password',
                                prefixIcon: const Icon(Icons.lock_person_outlined),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                  icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                ),
                              ),
                              validator: (v) => v != _passwordCtrl.text ? 'Passwords do not match' : null,
                              obscureText: _obscureConfirm,
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: auth.loading ? null : _onRegister,
                                child: auth.loading
                                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Text('Create account'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const LoginPage()),
                              ),
                              child: const Text('Already have an account? Login'),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onRegister() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthViewModel>();
    final ok = await auth.register(
      firstName: _firstCtrl.text.trim(),
      lastName: _lastCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      confirmPassword: _confirmCtrl.text,
      phone: _phoneCtrl.text.trim(),
      gender: _gender!,
    );
    if (ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registered successfully')));
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
    } else {
      if (!mounted) return;
      final err = context.read<AuthViewModel>().error ?? 'Registration failed';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }
}
