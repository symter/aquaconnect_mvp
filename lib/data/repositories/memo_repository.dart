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

  /// Image bytes for one of a memo's [Memo.photoIds].
  Future<Uint8List> loadPhoto(String photoId);
}
