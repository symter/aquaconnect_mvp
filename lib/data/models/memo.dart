import 'dart:typed_data';

enum MemoAuthorType {
  institute,
  farm;

  static MemoAuthorType fromKey(String key) =>
      key == 'farm' ? MemoAuthorType.farm : MemoAuthorType.institute;

  String get key => this == MemoAuthorType.farm ? 'farm' : 'institute';
}

class Memo {
  const Memo({
    required this.id,
    required this.orgId,
    required this.authorType,
    required this.authorName,
    required this.content,
    required this.tags,
    required this.createdAt,
    this.farmId,
    this.farmName,
    this.photoCount = 0,
    this.photoIds = const [],
    this.readByFarm = false,
  });

  final String id;
  final String orgId;
  final String? farmId;

  /// Denormalized display name — "미지정" when [farmId] is null.
  final String? farmName;
  final MemoAuthorType authorType;
  final String authorName;
  final String content;
  final List<String> tags;
  /// Total photos attached. Seed memos predate real photo storage, so this
  /// can exceed [photoIds].length — those extras render as placeholders.
  final int photoCount;

  /// IDs of stored photos, loadable via MemoRepository.loadPhoto.
  final List<String> photoIds;
  final bool readByFarm;
  final DateTime createdAt;

  String get farmLabel => farmName ?? '미지정';

  factory Memo.fromJson(Map<String, dynamic> json) => Memo(
        id: json['id'] as String,
        orgId: json['orgId'] as String,
        farmId: json['farmId'] as String?,
        farmName: json['farmName'] as String?,
        authorType: MemoAuthorType.fromKey(json['authorType'] as String),
        authorName: json['authorName'] as String,
        content: json['content'] as String,
        tags: (json['tags'] as List<dynamic>? ?? const []).cast<String>(),
        photoCount: json['photoCount'] as int? ?? 0,
        photoIds: (json['photoIds'] as List<dynamic>? ?? const []).cast<String>(),
        readByFarm: json['readByFarm'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// A photo taken/picked in the composer, already downscaled on-device.
class MemoPhotoUpload {
  const MemoPhotoUpload({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;
}
