import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';

class PaymentsService {
  final String baseUrl;
  PaymentsService({String? baseUrl}) : baseUrl = baseUrl ?? ApiConstants.baseUrl;

  Uri _u(String path) => Uri.parse('$baseUrl$path');
  Map<String, String> _authHeaders(String token) => {
        HttpHeaders.authorizationHeader: 'Bearer $token',
        HttpHeaders.contentTypeHeader: 'application/json',
      };

  Map<String, dynamic> _decode(http.Response res) {
    final body = jsonDecode(res.body.isEmpty ? '{}' : res.body) as Map<String, dynamic>;
    return body;
  }

  String? _extractError(Map<String, dynamic> body) {
    if (body['message'] is String) return body['message'] as String;
    if (body['error'] is String) return body['error'] as String;
    return null;
  }

  Future<String> createChapaCheckout(String token, {required String groupId, String? roomId}) async {
    final payload = <String, dynamic>{'groupId': groupId};
    if (roomId != null && roomId.isNotEmpty) payload['roomId'] = roomId;

    final res = await http.post(
      _u('/api/payments/chapa/checkout'),
      headers: _authHeaders(token),
      body: jsonEncode(payload),
    );
    final body = _decode(res);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(_extractError(body) ?? 'Failed to create checkout');
    }
    final data = body['data'] as Map<String, dynamic>?;
    final url = data?['checkout_url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('No checkout_url returned');
    }
    return url;
  }

  Future<void> markPaid(String token, {required String groupId}) async {
    final res = await http.post(
      _u('/api/payments/chapa/mark-paid'),
      headers: _authHeaders(token),
      body: jsonEncode({'groupId': groupId}),
    );
    final body = _decode(res);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(_extractError(body) ?? 'Failed to mark paid');
    }
  }
}
