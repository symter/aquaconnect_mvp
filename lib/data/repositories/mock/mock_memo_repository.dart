import 'dart:async';

import '../../mock/mock_seed.dart';
import '../../models/memo.dart';
import '../memo_repository.dart';

class MockMemoRepository implements MemoRepository {
  MockMemoRepository() {
    _memos = MockSeed.initialMemos(DateTime.now());
  }

  late List<Memo> _memos;
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
  Future<Memo> addMemo({
    String? farmId,
    String? farmName,
    required String content,
    required List<String> tags,
    int photoCount = 0,
  }) async {
    final memo = Memo(
      id: 'memo-${DateTime.now().microsecondsSinceEpoch}',
      orgId: MockSeed.orgId,
      farmId: farmId,
      farmName: farmName,
      authorType: MemoAuthorType.institute,
      authorName: '수산질병관리원 · ${MockSeed.currentMember.name}',
      content: content,
      tags: tags,
      createdAt: DateTime.now(),
      photoCount: photoCount,
    );
    _memos = [memo, ..._memos];
    _emit();
    return memo;
  }

  @override
  Future<Memo> updateMemo({required String id, required String content}) async {
    final index = _memos.indexWhere((m) => m.id == id);
    if (index == -1) throw StateError('memo not found: $id');
    final old = _memos[index];
    if (old.content == content) return old;
    final updated = old.copyWith(
      content: content,
      edits: [
        ...old.edits,
        MemoEdit(editorName: MockSeed.currentMember.name, editedAt: DateTime.now(), previousContent: old.content),
      ],
    );
    _memos = [..._memos]..[index] = updated;
    _emit();
    return updated;
  }
}
