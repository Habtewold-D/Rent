import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';

class AdminUsersService {
  final http.Client _client;
  AdminUsersService({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> getUsers(
    String token, {
    String? search,
    String? role,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'limit': '$limit',
    };
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (role != null && role.isNotEmpty) params['role'] = role;

    final uri = Uri.parse(ApiConstants.baseUrl + ApiConstants.adminUsers)
        .replace(queryParameters: params);

    final res = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    final body = _decode(res.body);
    if (res.statusCode != 200 || body['success'] != true) {
      final msg = _extractError(body) ?? 'Failed to fetch users';
      throw Exception('$msg (HTTP ${res.statusCode})');
    }
    final data = body['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw Exception('Invalid response');
  }

  Map<String, dynamic> _decode(String s) {
    try {
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return {'success': false, 'message': 'Invalid server response'};
    }
  }

  String? _extractError(Map<String, dynamic> body) {
    final candidates = [body['message'], body['error'], body['errors']?.toString()];
    for (final c in candidates) {
      if (c is String && c.trim().isNotEmpty) return c;
    }
    return null;
  }
}
