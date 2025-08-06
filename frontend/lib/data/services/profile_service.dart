import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';

class ProfileService {
  ProfileService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Map<String, String> _headersWithAuth(String token) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> getProfile(String token) async {
    final res = await _client.get(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.profile}'),
      headers: _headersWithAuth(token),
    );
    final body = _safeJson(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(_extractErrorMessage(res, body, fallback: 'Failed to load profile'));
  }

  Future<Map<String, dynamic>> updateProfile(
    String token, {
    String? firstName,
    String? lastName,
    String? phone,
    int? age,
    String? profession,
    String? religion,
  }) async {
    final payload = <String, dynamic>{};
    if (firstName != null) payload['firstName'] = firstName;
    if (lastName != null) payload['lastName'] = lastName;
    if (phone != null) payload['phone'] = phone;
    if (age != null) payload['age'] = age;
    if (profession != null) payload['profession'] = profession;
    if (religion != null) payload['religion'] = religion;

    final res = await _client.put(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.profile}'),
      headers: _headersWithAuth(token),
      body: jsonEncode(payload),
    );
    final body = _safeJson(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(_extractErrorMessage(res, body, fallback: 'Failed to update profile'));
  }

  Future<Map<String, dynamic>> changePassword(
    String token, {
    required String currentPassword,
    required String newPassword,
  }) async {
    final res = await _client.put(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.changePassword}'),
      headers: _headersWithAuth(token),
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );
    final body = _safeJson(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(_extractErrorMessage(res, body, fallback: 'Failed to change password'));
  }

  Future<Map<String, dynamic>> getLandlordStatus(String token) async {
    final res = await _client.get(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.landlordStatus}'),
      headers: _headersWithAuth(token),
    );
    final body = _safeJson(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(_extractErrorMessage(res, body, fallback: 'Failed to get landlord status'));
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
    final candidates = <String?>[
      body['message']?.toString(),
      body['error']?.toString(),
    ];
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
    candidates.add(res.reasonPhrase);
    return candidates.firstWhere((e) => e != null && e.trim().isNotEmpty, orElse: () => fallback)!;
  }
}
