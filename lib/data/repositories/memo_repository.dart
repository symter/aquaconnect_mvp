import 'dart:typed_data';

import '../models/memo.dart';

abstract class MemoRepository {
  /// Live-updating memo feed, newest first. [farmId] filters to one farm;
  /// null returns every memo across the org.
  Stream<List<Memo>> watchMemos({String? farmId});

  Future<Memo> addMemo({
    String? farmId,
    String? farmName,
    required String content,
    required List<String> tags,
    List<MemoPhotoUpload> photos,
  });

  /// Replaces a memo's content and appends the previous content to its edit
  /// log, attributed to the signed-in member.
  Future<Memo> updateMemo({required String id, required String content});

  /// Deletes a memo (and its photos).
  Future<void> deleteMemo(String id);

  /// Image bytes for one of a memo's [Memo.photoIds].
  Future<Uint8List> loadPhoto(String photoId);
}
