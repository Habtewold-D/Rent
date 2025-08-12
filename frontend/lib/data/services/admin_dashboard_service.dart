import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';

class AdminDashboardService {
  Future<Map<String, dynamic>> getSummary(String token) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.adminSummary}');
    final res = await http.get(uri, headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    });
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = json.decode(res.body) as Map<String, dynamic>;
      if (body['success'] == true && body['data'] is Map<String, dynamic>) {
        return body['data'] as Map<String, dynamic>;
      }
      throw Exception(body['message'] ?? 'Failed to load summary');
    }
    throw Exception('Failed to load summary: ${res.statusCode} ${res.reasonPhrase}');
  }
}
