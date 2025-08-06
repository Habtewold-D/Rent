import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../services/profile_service.dart';
import '../../core/constants/api_constants.dart';

class LandlordService {
  LandlordService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Map<String, String> _headersWithAuth(String token) => {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> requestVerification(
    String token, {
    required List<int> nationalIdBytes,
    required String nationalIdFilename,
    required List<int> propertyDocBytes,
    required String propertyDocFilename,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.landlordRequestVerification}');
    final req = http.MultipartRequest('POST', uri);
    req.headers.addAll(_headersWithAuth(token));

    req.files.add(http.MultipartFile.fromBytes(
      'nationalId',
      nationalIdBytes,
      filename: nationalIdFilename,
      contentType: _inferMediaType(nationalIdFilename),
    ));
    req.files.add(http.MultipartFile.fromBytes(
      'propertyDocument',
      propertyDocBytes,
      filename: propertyDocFilename,
      contentType: _inferMediaType(propertyDocFilename),
    ));

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    final body = _safeJson(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(_extractErrorMessage(res, body, fallback: 'Failed to submit verification'));
  }

  Future<Map<String, dynamic>> getMyRequest(String token) async {
    final res = await _client.get(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.landlordMyRequest}'),
      headers: _headersWithAuth(token),
    );
    final body = _safeJson(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(_extractErrorMessage(res, body, fallback: 'Failed to get landlord request'));
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
      if (msgs.isNotEmpty) return msgs.join('\n');
    }
    final candidates = <String?>[
      body['error']?.toString(),
      body['message']?.toString(),
      res.reasonPhrase,
    ];
    return candidates.firstWhere((e) => e != null && e.trim().isNotEmpty, orElse: () => fallback)!;
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
    if (lower.endsWith('.pdf')) return MediaType('application', 'pdf');
    return null; // fallback lets http set default
  }
}
