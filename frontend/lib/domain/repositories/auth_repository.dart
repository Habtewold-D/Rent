abstract class AuthRepository {
  Future<Map<String, dynamic>> login(String email, String password);
  Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? confirmPassword,
    required String phone,
    required String gender,
  });
}
