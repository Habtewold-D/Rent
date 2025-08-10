import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';

class MatchingService {
  final String baseUrl;
  MatchingService({String? baseUrl}) : baseUrl = baseUrl ?? ApiConstants.baseUrl;

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

  Future<Map<String, dynamic>> joinRoom(
    String token,
    String roomId, {
    required int userAge,
    required int desiredGroupSize,
    String religionPreference = 'any',
    String? genderPreference,
  }) async {
    final payload = {
      'userAge': userAge,
      'desiredGroupSize': desiredGroupSize,
      'religionPreference': religionPreference,
      if (genderPreference != null && genderPreference.isNotEmpty) 'genderPreference': genderPreference,
    };
    final res = await http.post(
      _u('${ApiConstants.joinRoom}/$roomId'),
      headers: _authHeaders(token),
      body: jsonEncode(payload),
    );
    final body = _decode(res);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(_extractError(body) ?? 'Failed to fetch groups');
    }
    return body['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createGroup(
    String token,
    String roomId, {
    required int userAge,
    required int desiredGroupSize,
    String religionPreference = 'any',
  }) async {
    final res = await http.post(
      _u('${ApiConstants.createGroup}/$roomId'),
      headers: _authHeaders(token),
      body: jsonEncode({
        'userAge': userAge,
        'desiredGroupSize': desiredGroupSize,
        'religionPreference': religionPreference,
      }),
    );
    final body = _decode(res);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(_extractError(body) ?? 'Failed to create group');
    }
    return body['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> joinGroup(
    String token,
    String groupId, {
    int? userAge,
    String? religionPreference,
  }) async {
    final payload = <String, dynamic>{};
    if (userAge != null) payload['userAge'] = userAge;
    if (religionPreference != null && religionPreference.isNotEmpty) {
      payload['religionPreference'] = religionPreference;
    }
    final res = await http.post(
      _u('${ApiConstants.groupsBase}/$groupId/join'),
      headers: _authHeaders(token),
      body: jsonEncode(payload),
    );
    final body = _decode(res);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(_extractError(body) ?? 'Failed to join group');
    }
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> leaveGroup(
    String token,
    String groupId,
  ) async {
    final res = await http.delete(
      _u('${ApiConstants.groupsBase}/$groupId/leave'),
      headers: _authHeaders(token),
    );
    final body = _decode(res);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(_extractError(body) ?? 'Failed to leave group');
    }
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{};
  }

  Future<List<dynamic>> getMyGroups(
    String token,
  ) async {
    final res = await http.get(
      _u(ApiConstants.myGroups),
      headers: _authHeaders(token),
    );
    final body = _decode(res);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(_extractError(body) ?? 'Failed to fetch my groups');
    }
    final data = body['data'];
    if (data is List) return data;
    if (data is Map && data['groups'] is List) return data['groups'] as List<dynamic>;
    return <dynamic>[];
  }

  Future<List<dynamic>> getNotifications(
    String token,
  ) async {
    final res = await http.get(
      _u(ApiConstants.notifications),
      headers: _authHeaders(token),
    );
    final body = _decode(res);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(_extractError(body) ?? 'Failed to fetch notifications');
    }
    final data = body['data'];
    if (data is List) return data;
    if (data is Map && data['notifications'] is List) return data['notifications'] as List<dynamic>;
    return <dynamic>[];
  }
}
