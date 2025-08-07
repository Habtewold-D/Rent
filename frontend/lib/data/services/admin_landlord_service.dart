import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';

class AdminLandlordService {
  final http.Client _client;
  AdminLandlordService({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> getRequests(
    String token, {
    String? status,
    String? search,
    int page = 1,
    int limit = 10,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'limit': '$limit',
    };
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final uri = Uri.parse(ApiConstants.baseUrl + ApiConstants.adminLandlordRequests)
        .replace(queryParameters: params);

    final res = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    final body = _decode(res);
    if (res.statusCode != 200 || body['success'] != true) {
      final msg = _extractError(body) ?? 'Failed to fetch requests';
      final snippet = _bodySnippet(res.body);
      throw Exception('$msg (HTTP ${res.statusCode})$snippet');
    }
    final data = body['data'];
    if (data is Map<String, dynamic>) {
      return Map<String, dynamic>.from(data);
    }
    throw Exception('Invalid response shape for requests');
  }

  Future<Map<String, dynamic>> getStats(String token) async {
    final uri = Uri.parse(ApiConstants.baseUrl + ApiConstants.adminLandlordRequestStats);
    final res = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );
    final body = _decode(res);
    if (res.statusCode != 200 || body['success'] != true) {
      final msg = _extractError(body) ?? 'Failed to fetch stats';
      final snippet = _bodySnippet(res.body);
      throw Exception('$msg (HTTP ${res.statusCode})$snippet');
    }
    final data = body['data'];
    final stats = (data is Map<String, dynamic>) ? data['stats'] : null;
    if (stats is Map<String, dynamic>) {
      return Map<String, dynamic>.from(stats);
    }
    throw Exception('Invalid response shape for stats');
  }

  Future<Map<String, dynamic>> reviewRequest(
    String token, {
    required String id,
    required String status, // 'approved' | 'rejected'
    String? adminNotes,
  }) async {
    final uri = Uri.parse(
      ApiConstants.baseUrl + '${ApiConstants.adminReviewLandlordRequest}/$id/review',
    );

    final res = await _client.put(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'status': status,
        if (adminNotes != null) 'adminNotes': adminNotes,
      }),
    );

    final body = _decode(res);
    if (res.statusCode != 200 || body['success'] != true) {
      final msg = _extractError(body) ?? 'Failed to review request';
      final snippet = _bodySnippet(res.body);
      throw Exception('$msg (HTTP ${res.statusCode})$snippet');
    }
    final data = body['data'];
    final req = (data is Map<String, dynamic>) ? data['request'] : null;
    if (req is Map<String, dynamic>) {
      return Map<String, dynamic>.from(req);
    }
    throw Exception('Invalid response shape for review');
  }

  Map<String, dynamic> _decode(http.Response res) {
    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return {
        'success': false,
        'message': 'Invalid server response (${res.statusCode})',
      };
    }
  }

  String? _extractError(Map<String, dynamic> body) {
    final candidates = [
      body['message'],
      body['error'],
      body['errors']?.toString(),
    ];
    for (final c in candidates) {
      if (c is String && c.trim().isNotEmpty) return c;
    }
    return null;
  }

  String _bodySnippet(String body) {
    if (body.isEmpty) return '';
    final cleaned = body.replaceAll(RegExp(r'\s+'), ' ');
    final take = cleaned.length > 140 ? 140 : cleaned.length;
    return ': ' + cleaned.substring(0, take);
  }
}
