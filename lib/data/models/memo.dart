import 'dart:typed_data';

enum MemoAuthorType {
  institute,
  farm;

  static MemoAuthorType fromKey(String key) =>
      key == 'farm' ? MemoAuthorType.farm : MemoAuthorType.institute;

  String get key => this == MemoAuthorType.farm ? 'farm' : 'institute';
}

/// One entry in a memo's edit log: who changed it, when, and what the
/// content said *before* that edit.
class MemoEdit {
  const MemoEdit({required this.editorName, required this.editedAt, required this.previousContent});

  final String editorName;
  final DateTime editedAt;
  final String previousContent;

  factory MemoEdit.fromJson(Map<String, dynamic> json) => MemoEdit(
        editorName: json['editorName'] as String,
        editedAt: DateTime.parse(json['editedAt'] as String),
        previousContent: json['previousContent'] as String,
      );
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
    this.edits = const [],
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

  /// Edit log, oldest first. Empty when the memo was never edited.
  final List<MemoEdit> edits;

  bool get isEdited => edits.isNotEmpty;

  String get farmLabel => farmName ?? '미지정';

  Memo copyWith({String? content, List<MemoEdit>? edits}) => Memo(
        id: id,
        orgId: orgId,
        farmId: farmId,
        farmName: farmName,
        authorType: authorType,
        authorName: authorName,
        content: content ?? this.content,
        tags: tags,
        photoCount: photoCount,
        readByFarm: readByFarm,
        createdAt: createdAt,
        edits: edits ?? this.edits,
      );

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
        edits: (json['edits'] as List<dynamic>? ?? const [])
            .map((e) => MemoEdit.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// A photo taken/picked in the composer, already downscaled on-device.
class MemoPhotoUpload {
  const MemoPhotoUpload({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;
}
