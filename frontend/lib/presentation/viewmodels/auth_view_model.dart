import 'package:flutter/foundation.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._repo);
  final AuthRepository _repo;

  bool _loading = false;
  String? _error;
  String? _token;

  bool get loading => _loading;
  String? get error => _error;
  String? get token => _token;

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    try {
      final res = await _repo.login(email, password);
      _token = res['token'] as String?;
      _error = null;
      return true;
    } catch (e) {
      _error = _cleanError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? confirmPassword,
    required String phone,
    required String gender,
  }) async {
    _setLoading(true);
    try {
      final res = await _repo.register(
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
        confirmPassword: confirmPassword,
        phone: phone,
        gender: gender,
      );
      _token = res['token'] as String?; // if backend returns token
      _error = null;
      return true;
    } catch (e) {
      _error = _cleanError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  String _cleanError(Object e) {
    final s = e.toString();
    if (s.startsWith('Exception: ')) return s.substring('Exception: '.length);
    return s;
  }
}
