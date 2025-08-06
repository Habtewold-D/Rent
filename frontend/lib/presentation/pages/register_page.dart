import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/validators.dart';
import '../viewmodels/auth_view_model.dart';
import '../../core/constants/theme_constants.dart';
import 'login_page.dart';

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
  bool _obscure = true;
  String? _gender; // 'male' or 'female'

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
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _firstCtrl,
                              decoration: const InputDecoration(labelText: 'First name', prefixIcon: Icon(Icons.badge_outlined)),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _lastCtrl,
                              decoration: const InputDecoration(labelText: 'Last name', prefixIcon: Icon(Icons.badge_outlined)),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _emailCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phoneCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Phone (Ethiopia)',
                                prefixIcon: Icon(Icons.phone_outlined),
                                hintText: '+2519XXXXXXXX or 09XXXXXXXX',
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Gender',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              value: _gender,
                              items: const [
                                DropdownMenuItem(value: 'male', child: Text('Male')),
                                DropdownMenuItem(value: 'female', child: Text('Female')),
                              ],
                              onChanged: (v) => setState(() => _gender = v),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passwordCtrl,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                  icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                ),
                              ),
                              obscureText: _obscure,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _confirmCtrl,
                              decoration: InputDecoration(
                                labelText: 'Confirm password',
                                prefixIcon: const Icon(Icons.lock_person_outlined),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                  icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                ),
                              ),
                              obscureText: _obscure,
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
                            // Errors are shown via SnackBars only
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
    // Manual validation; show errors via SnackBar (no inline form errors)
    final firstErr = Validators.nonEmpty(_firstCtrl.text, 'First name');
    final lastErr = Validators.nonEmpty(_lastCtrl.text, 'Last name');
    final emailErr = Validators.email(_emailCtrl.text);
    final passErr = Validators.password(_passwordCtrl.text);
    final phoneErr = Validators.ethiopianPhone(_phoneCtrl.text);
    final errs = [firstErr, lastErr, emailErr, passErr].whereType<String>().toList();
    if (errs.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errs.first), backgroundColor: Colors.redAccent),
      );
      return;
    }
    if (phoneErr != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(phoneErr), backgroundColor: Colors.redAccent),
      );
      return;
    }
    if (_gender == null || (_gender != 'male' && _gender != 'female')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select gender'), backgroundColor: Colors.redAccent),
      );
      return;
    }
    if (_passwordCtrl.text != _confirmCtrl.text) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match'), backgroundColor: Colors.redAccent),
      );
      return;
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registered successfully'), backgroundColor: Colors.green),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } else {
      if (!mounted) return;
      final msg = auth.error ?? 'Registration failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
      );
    }
  }
}
