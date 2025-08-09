class RoomImage {
  final String id;
  final String imageUrl;
  final bool? isPrimary;
  final String? caption;
  final int? displayOrder;

  RoomImage({
    required this.id,
    required this.imageUrl,
    this.isPrimary,
    this.caption,
    this.displayOrder,
  });

  factory RoomImage.fromJson(Map<String, dynamic> json) {
    return RoomImage(
      id: json['id']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      isPrimary: json['isPrimary'] is bool ? json['isPrimary'] as bool : null,
      caption: json['caption']?.toString(),
      displayOrder: _asInt(json['displayOrder']),
    );
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }
}
