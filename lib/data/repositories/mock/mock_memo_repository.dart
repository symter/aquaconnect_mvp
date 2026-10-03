import 'dart:async';
import 'dart:typed_data';

import '../../mock/mock_seed.dart';
import '../../models/memo.dart';
import '../memo_repository.dart';

class MockMemoRepository implements MemoRepository {
  MockMemoRepository() {
    _memos = MockSeed.initialMemos(DateTime.now());
  }

  late List<Memo> _memos;
  final _photos = <String, Uint8List>{};
  final _controller = StreamController<List<Memo>>.broadcast();

  List<Memo> get _sorted => [..._memos]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  void _emit() => _controller.add(_sorted);

  @override
  Stream<List<Memo>> watchMemos({String? farmId}) {
    // Stream.multi replays the current list to every new subscriber (not
    // just the very first one ever) — see MockAuthRepository for why a
    // plain broadcast controller's onListen isn't enough here.
    return Stream<List<Memo>>.multi((controller) {
      controller.add(_sorted);
      final sub = _controller.stream.listen(controller.add, onDone: controller.close);
      controller.onCancel = sub.cancel;
    }).map((List<Memo> memos) => farmId == null ? memos : memos.where((m) => m.farmId == farmId).toList());
  }

  @override
  Future<Uint8List> loadPhoto(String photoId) async {
    final bytes = _photos[photoId];
    if (bytes == null) throw Exception('사진을 찾을 수 없습니다.');
    return bytes;
  }

  @override
  Future<Memo> addMemo({
    String? farmId,
    String? farmName,
    required String content,
    required List<String> tags,
    List<MemoPhotoUpload> photos = const [],
  }) async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final photoIds = <String>[];
    for (var i = 0; i < photos.length; i++) {
      final id = 'photo-$stamp-$i';
      _photos[id] = photos[i].bytes;
      photoIds.add(id);
    }
    final memo = Memo(
      id: 'memo-$stamp',
      orgId: MockSeed.orgId,
      farmId: farmId,
      farmName: farmName,
      authorType: MemoAuthorType.institute,
      authorName: '수산질병관리원 · ${MockSeed.currentMember.name}',
      content: content,
      tags: tags,
      createdAt: DateTime.now(),
      photoCount: photoIds.length,
      photoIds: photoIds,
    );
    _memos = [memo, ..._memos];
    _emit();
    return memo;
  }

  @override
  Future<void> deleteMemo(String id) async {
    _memos = _memos.where((m) => m.id != id).toList();
    _emit();
  }
}
