import 'room_image.dart';

class Room {
  final String id;
  final String city;
  final String address;
  final double monthlyRent;
  final String roomType;
  final int maxOccupants;
  final String genderPreference;
  final bool isAvailable;
  final bool isApproved;
  final int? viewCount;
  final DateTime? createdAt;
  final List<RoomImage> images;

  Room({
    required this.id,
    required this.city,
    required this.address,
    required this.monthlyRent,
    required this.roomType,
    required this.maxOccupants,
    required this.genderPreference,
    required this.isAvailable,
    required this.isApproved,
    required this.images,
    this.viewCount,
    this.createdAt,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    List<dynamic> imgsRaw = [];
    if (json['roomImages'] is List) imgsRaw = json['roomImages'] as List;
    final images = imgsRaw
        .map((e) => e is Map<String, dynamic>
            ? RoomImage.fromJson(e)
            : RoomImage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return Room(
      id: json['id']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      monthlyRent: _asDouble(json['monthlyRent']) ?? 0,
      roomType: json['roomType']?.toString() ?? '',
      maxOccupants: _asInt(json['maxOccupants']) ?? 0,
      genderPreference: json['genderPreference']?.toString() ?? '',
      isAvailable: _asBool(json['isAvailable']) ?? true,
      isApproved: _asBool(json['isApproved']) ?? false,
      viewCount: _asInt(json['viewCount']),
      createdAt: _asDate(json['createdAt']),
      images: images,
    );
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static bool? _asBool(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;
    if (v is String) return v.toLowerCase() == 'true';
    if (v is num) return v != 0;
    return null;
  }

  static DateTime? _asDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
