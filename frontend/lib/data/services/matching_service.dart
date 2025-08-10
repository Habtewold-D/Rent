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

  Future<Map<String, dynamic>> getNotifications(
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
    final data = (body['data'] is Map<String, dynamic>) ? body['data'] as Map<String, dynamic> : <String, dynamic>{};
    final notifications = (data['notifications'] is List) ? data['notifications'] as List<dynamic> : <dynamic>[];
    final unreadCount = int.tryParse('${data['unreadCount'] ?? 0}') ?? 0;
    return {
      'notifications': notifications,
      'unreadCount': unreadCount,
    };
  }

  Future<void> markNotificationRead(String token, String notificationId) async {
    final res = await http.put(
      _u('${ApiConstants.notificationsReadBase}/$notificationId/read'),
      headers: _authHeaders(token),
    );
    final body = _decode(res);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(_extractError(body) ?? 'Failed to mark notification as read');
    }
  }

  Future<void> markAllNotificationsRead(String token) async {
    final res = await http.put(
      _u('${ApiConstants.notificationsReadBase}/read-all'),
      headers: _authHeaders(token),
    );
    final body = _decode(res);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(_extractError(body) ?? 'Failed to mark all notifications as read');
    }
  }

  Future<void> sendTargetedNotification(
    String token, {
    required List<String> userIds,
    required String type,
    String? title,
    String? message,
    Map<String, dynamic>? data,
  }) async {
    final payload = <String, dynamic>{
      'userIds': userIds,
      'type': type,
      if (title != null) 'title': title,
      if (message != null) 'message': message,
      if (data != null) 'data': data,
    };
    final res = await http.post(
      _u(ApiConstants.notificationsSend),
      headers: _authHeaders(token),
      body: jsonEncode(payload),
    );
    final body = _decode(res);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(_extractError(body) ?? 'Failed to send notifications');
    }
  }
}
