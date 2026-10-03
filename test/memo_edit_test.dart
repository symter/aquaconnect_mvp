import 'package:flutter_test/flutter_test.dart';

import 'package:aquaconnect_mvp/data/models/memo.dart';
import 'package:aquaconnect_mvp/data/repositories/mock/mock_memo_repository.dart';

void main() {
  test('updateMemo replaces content and logs the previous text', () async {
    final repo = MockMemoRepository();
    final memo = await repo.addMemo(content: '3수조 폐사 5마리', tags: const []);

    final updated = await repo.updateMemo(id: memo.id, content: '  3수조 폐사 7마리 ');

    expect(updated.content, '3수조 폐사 7마리');
    expect(updated.isEdited, isTrue);
    expect(updated.editCount, 1);
    expect(updated.edits.single.previousContent, '3수조 폐사 5마리');
    final feed = await repo.watchMemos().first;
    expect(feed.firstWhere((m) => m.id == memo.id).content, '3수조 폐사 7마리');
  });

  test('saving unchanged content does not add an edit; empty content is rejected', () async {
    final repo = MockMemoRepository();
    final memo = await repo.addMemo(content: '방문 완료', tags: const []);

    final same = await repo.updateMemo(id: memo.id, content: '방문 완료');
    expect(same.isEdited, isFalse);
    await expectLater(repo.updateMemo(id: memo.id, content: '   '), throwsException);
  });

  test('fromJson reads editCount even when the edit log is withheld', () {
    final memo = Memo.fromJson({
      'id': 'm1',
      'orgId': 'o1',
      'authorType': 'institute',
      'authorName': '수산질병관리원 · 김철수',
      'content': '고친 내용',
      'tags': <String>[],
      'createdAt': '2026-10-03T00:00:00Z',
      'editCount': 2,
      'edits': <dynamic>[],
    });
    expect(memo.isEdited, isTrue);
    expect(memo.edits, isEmpty);
  });
}
