import 'package:flutter/foundation.dart';
import '../../data/services/profile_service.dart';

class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel(this._service);
  final ProfileService _service;

  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _user; // server user object
  Map<String, dynamic>? _landlordStatus; // { isLandlord, isVerified, canRequestVerification }

  bool get loading => _loading;
  String? get error => _error;
  Map<String, dynamic>? get user => _user;
  Map<String, dynamic>? get landlordStatus => _landlordStatus;

  Future<void> loadAll(String token) async {
    _setLoading(true);
    try {
      final profile = await _service.getProfile(token);
      _user = profile['data']?['user'] as Map<String, dynamic>?;
      final status = await _service.getLandlordStatus(token);
      _landlordStatus = status['data'] as Map<String, dynamic>?;
      _error = null;
    } catch (e) {
      _error = _cleanError(e);
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> changePassword(
    String token, {
    required String currentPassword,
    required String newPassword,
  }) async {
    _setLoading(true);
    try {
      await _service.changePassword(
        token,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      _error = null;
      return true;
    } catch (e) {
      _error = _cleanError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateProfile(
    String token, {
    String? firstName,
    String? lastName,
    String? phone,
    int? age,
    String? profession,
    String? religion,
  }) async {
    _setLoading(true);
    try {
      final res = await _service.updateProfile(
        token,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        age: age,
        profession: profession,
        religion: religion,
      );
      _user = res['data']?['user'] as Map<String, dynamic>?;
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
