import 'package:flutter/foundation.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._repo);
  final AuthRepository _repo;

  bool _loading = false;
  String? _error;
  String? _token;
  String? _role;
  String? _userName;
  String? _userEmail;
  String? _userGender;
  int? _userAge;
  String? _userProfession;
  String? _userReligion;

  bool get loading => _loading;
  String? get error => _error;
  String? get token => _token;
  String? get role => _role;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get userGender => _userGender;
  int? get userAge => _userAge;
  String? get userProfession => _userProfession;
  String? get userReligion => _userReligion;

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    try {
      final res = await _repo.login(email, password);
      _token = res['data']?['token'] as String?;
      final user = res['data']?['user'] as Map<String, dynamic>?;
      _role = user?['role'] as String?;
      final first = user?['firstName'] as String?;
      final last = user?['lastName'] as String?;
      _userName = [first, last].where((s) => (s ?? '').isNotEmpty).join(' ').trim();
      _userEmail = user?['email'] as String?;
      _userGender = user?['gender']?.toString();
      final dynamic _ageVal = user?['age'];
      if (_ageVal is int) {
        _userAge = _ageVal;
      } else {
        _userAge = int.tryParse(_ageVal?.toString() ?? '');
      }
      _userProfession = user?['profession']?.toString();
      _userReligion = user?['religion']?.toString();
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
      // Flexible parsing: token can be at data.token or top-level token
      _token = (res['data']?['token'] as String?) ?? (res['token'] as String?);
      final user = (res['data']?['user'] as Map<String, dynamic>?) ?? (res['user'] as Map<String, dynamic>?);
      _role = user?['role'] as String?;
      final first = user?['firstName'] as String?;
      final last = user?['lastName'] as String?;
      _userName = [first, last].where((s) => (s ?? '').isNotEmpty).join(' ').trim();
      _userEmail = user?['email'] as String?;
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

  // Clears all auth state
  void logout() {
    _token = null;
    _role = null;
    _userName = null;
    _userEmail = null;
    _userGender = null;
    _userAge = null;
    _userProfession = null;
    _userReligion = null;
    _error = null;
    notifyListeners();
  }
}
