import '../../domain/repositories/auth_repository.dart';
import '../services/auth_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({AuthService? service}) : _service = service ?? AuthService();
  final AuthService _service;

  @override
  Future<Map<String, dynamic>> login(String email, String password) {
    return _service.login(email, password);
  }

  @override
  Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? confirmPassword,
    required String phone,
    required String gender,
  }) {
    return _service.register(
      firstName: firstName,
      lastName: lastName,
      email: email,
      password: password,
      confirmPassword: confirmPassword,
      phone: phone,
      gender: gender,
    );
  }
}
