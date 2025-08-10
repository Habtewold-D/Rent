import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../core/constants/api_constants.dart';
import '../models/room.dart';

// Simple holder for image bytes to upload
class UploadImage {
  final Uint8List bytes;
  final String filename;
  final String? contentType; // e.g. image/jpeg
  UploadImage({required this.bytes, required this.filename, this.contentType});
}

class RoomService {
  final String baseUrl;
  RoomService({String? baseUrl}) : baseUrl = baseUrl ?? ApiConstants.baseUrl;

  // Enum options mirrored from backend Room model (removed 'shared')
  static const List<String> roomTypes = ['single', 'studio', 'apartment'];
  static const List<String> genderPreferences = ['male', 'female', 'mixed'];

  Uri _u(String path, [Map<String, dynamic>? q]) => Uri.parse('$baseUrl$path').replace(queryParameters: q?.map((k, v) => MapEntry(k, v.toString())));

  Map<String, String> _authHeaders(String token) => {
        HttpHeaders.authorizationHeader: 'Bearer $token',
        HttpHeaders.contentTypeHeader: 'application/json',
      };

  Future<Map<String, dynamic>> getMyListings(String token, {String status = 'all', int page = 1, int limit = 10}) async {
    final res = await http.get(
      _u('/api/rooms/my/listings', {
        'status': status,
        'page': page,
        'limit': limit,
      }),
      headers: {HttpHeaders.authorizationHeader: 'Bearer $token'},
    );
    final body = _decode(res);
    if (res.statusCode != 200 || body['success'] != true) {
      final msg = _extractError(body) ?? 'Failed to fetch your listings';
      throw Exception('$msg (HTTP ${res.statusCode})');
    }

    final data = body['data'] as Map<String, dynamic>;
    final roomsRaw = (data['rooms'] is List) ? data['rooms'] as List : <dynamic>[];
    final rooms = roomsRaw
        .map((e) => e is Map<String, dynamic> ? Room.fromJson(e) : Room.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final pagination = (data['pagination'] is Map<String, dynamic>) ? data['pagination'] as Map<String, dynamic> : {};
    return {
      'rooms': rooms,
      'pagination': pagination,
    };
  }

  Future<void> deleteRoom(String token, String roomId) async {
    final res = await http.delete(_u('/api/rooms/$roomId'), headers: _authHeaders(token));
    final body = _decode(res);
    if (res.statusCode != 200 || body['success'] != true) {
      final msg = _extractError(body) ?? 'Failed to delete room';
      throw Exception('$msg (HTTP ${res.statusCode})');
    }
  }

  Future<Map<String, dynamic>> getPublicRooms({
    String? city,
    String? roomType,
    String? genderPreference,
    num? minRent,
    num? maxRent,
    int page = 1,
    int limit = 10,
    String sortBy = 'createdAt',
    String sortOrder = 'DESC',
    bool includePending = true,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      'sortBy': sortBy,
      'sortOrder': sortOrder,
    };
    if (city != null && city.trim().isNotEmpty) query['city'] = city;
    if (roomType != null && roomType.trim().isNotEmpty) query['roomType'] = roomType;
    if (genderPreference != null && genderPreference.trim().isNotEmpty) query['genderPreference'] = genderPreference;
    if (minRent != null) query['minRent'] = minRent;
    if (maxRent != null) query['maxRent'] = maxRent;

    // Allow including pending (unapproved) rooms during development/testing
    if (includePending) query['includePending'] = true;
    final res = await http.get(_u('/api/rooms', query));
    final body = _decode(res);
    if (res.statusCode != 200 || body['success'] != true) {
      final msg = _extractError(body) ?? 'Failed to get rooms';
      throw Exception('$msg (HTTP ${res.statusCode})');
    }
    final data = body['data'] as Map<String, dynamic>;
    final roomsRaw = (data['rooms'] is List) ? data['rooms'] as List : <dynamic>[];
    final rooms = roomsRaw
        .map((e) => e is Map<String, dynamic> ? Room.fromJson(e) : Room.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final pagination = (data['pagination'] is Map<String, dynamic>) ? data['pagination'] as Map<String, dynamic> : {};
    return {
      'rooms': rooms,
      'pagination': pagination,
    };
  }

  Future<Room> createRoom(
    String token, {
    required Map<String, String> fields,
    List<UploadImage> images = const [],
  }) async {
    final uri = _u('/api/rooms');
    final req = http.MultipartRequest('POST', uri);
    req.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
    req.headers['Accept'] = 'application/json';
    // boundary set automatically
    req.fields.addAll(fields);

    for (final img in images) {
      final mt = _inferMediaType(img.filename) ?? MediaType('image', 'jpeg');
      req.files.add(http.MultipartFile.fromBytes(
        'images',
        img.bytes,
        filename: img.filename,
        contentType: mt,
      ));
    }

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    final body = _decode(res);
    if (res.statusCode != 201 || body['success'] != true) {
      final msg = _extractError(body) ?? 'Failed to create room';
      throw Exception('$msg (HTTP ${res.statusCode})');
    }
    final data = body['data'] as Map<String, dynamic>;
    final roomJson = data['room'] as Map<String, dynamic>;
    return Room.fromJson(roomJson);
  }

  Future<Room> updateRoom(
    String token,
    String roomId, {
    required Map<String, String> fields,
    List<UploadImage> images = const [], // optional: append new images
  }) async {
    final uri = _u('/api/rooms/$roomId');
    final req = http.MultipartRequest('PUT', uri);
    req.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
    req.headers['Accept'] = 'application/json';
    req.fields.addAll(fields);

    for (final img in images) {
      final mt = _inferMediaType(img.filename) ?? MediaType('image', 'jpeg');
      req.files.add(http.MultipartFile.fromBytes(
        'images',
        img.bytes,
        filename: img.filename,
        contentType: mt,
      ));
    }

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    final body = _decode(res);
    if (res.statusCode != 200 || body['success'] != true) {
      final msg = _extractError(body) ?? 'Failed to update room';
      throw Exception('$msg (HTTP ${res.statusCode})');
    }
    final data = body['data'] as Map<String, dynamic>;
    final roomJson = data['room'] as Map<String, dynamic>;
    return Room.fromJson(roomJson);
  }

  MediaType? _inferMediaType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return MediaType('image', 'jpeg');
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.gif')) return MediaType('image', 'gif');
    if (lower.endsWith('.bmp')) return MediaType('image', 'bmp');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    if (lower.endsWith('.heic')) return MediaType('image', 'heic');
    if (lower.endsWith('.heif')) return MediaType('image', 'heif');
    return null;
  }

  Map<String, dynamic> _decode(http.Response res) {
    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return {'success': false, 'message': 'Invalid server response (${res.statusCode})'};
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
}
