import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';

class AuthService {
  AuthService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _client.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.login}'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'email': email, 'password': password}),
    );
    final body = _safeJson(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(_extractErrorMessage(res, body, fallback: 'Login failed'));
  }

  Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? confirmPassword,
    required String phone,
    required String gender,
  }) async {
    final payload = {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'password': password,
      // Common alternates some backends expect
      'first_name': firstName,
      'last_name': lastName,
      'confirmPassword': confirmPassword ?? password,
      'password_confirmation': confirmPassword ?? password,
      // Backend required fields
      'phone': phone,
      'phone_number': phone,
      'gender': gender, // expects 'male' or 'female'
      'Gender': gender,
    };
    final res = await _client.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.register}'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      // Send both camelCase and snake_case to maximize compatibility with different backends.
      body: jsonEncode(payload),
    );
    final body = _safeJson(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(_extractErrorMessage(res, body, fallback: 'Registration failed'));
  }

  Map<String, dynamic> _safeJson(String raw) {
    try {
      final parsed = jsonDecode(raw);
      if (parsed is Map<String, dynamic>) return parsed;
      return {'message': parsed?.toString() ?? ''};
    } catch (_) {
      return {'message': raw};
    }
  }

  String _extractErrorMessage(http.Response res, Map<String, dynamic> body, {required String fallback}) {
    // Common patterns across backends
    final candidates = <String?>[
      body['message']?.toString(),
      body['error']?.toString(),
    ];
    // errors as array
    final errorsArr = body['errors'];
    if (errorsArr is List && errorsArr.isNotEmpty) {
      final msgs = <String>[];
      for (final item in errorsArr) {
        if (item is Map && item['msg'] != null) {
          msgs.add(item['msg'].toString());
        } else {
          msgs.add(item.toString());
        }
      }
      if (msgs.isNotEmpty) candidates.add(msgs.join('\n'));
    }
    // errors as object: { field: [msg] } or { field: msg }
    if (errorsArr is Map) {
      for (final v in errorsArr.values) {
        if (v is List && v.isNotEmpty) {
          candidates.add(v.first.toString());
          break;
        } else if (v != null) {
          candidates.add(v.toString());
          break;
        }
      }
    }
    // Some backends use validation key
    final validation = body['validation'];
    if (validation is String && validation.isNotEmpty) {
      candidates.add(validation);
    }
    // Fallback to status text if available
    candidates.add(res.reasonPhrase);
    return candidates.firstWhere((e) => e != null && e.trim().isNotEmpty, orElse: () => fallback)!;
  }
}
