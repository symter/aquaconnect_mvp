import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aquaconnect_mvp/data/mock/mock_seed.dart';
import 'package:aquaconnect_mvp/data/models/memo.dart';
import 'package:aquaconnect_mvp/data/repositories/mock/mock_memo_repository.dart';
import 'package:aquaconnect_mvp/data/services/digest_settings_store.dart';

void main() {
  test('comments are listed oldest first and counted on the memo', () async {
    final repo = MockMemoRepository();
    final memo = await repo.addMemo(content: '2수조 유영 이상', tags: const []);
    expect(memo.authorMemberId, MockSeed.currentMember.id);

    await repo.addComment(memoId: memo.id, content: ' 내일 다시 볼게요 ');
    final second = await repo.addComment(memoId: memo.id, content: '약품 준비해 둘게요');

    final comments = await repo.listComments(memo.id);
    expect(comments.map((c) => c.content), ['내일 다시 볼게요', '약품 준비해 둘게요']);
    expect((await repo.watchMemos().first).single.commentCount, 2);

    await repo.deleteComment(memoId: memo.id, commentId: second.id);
    expect((await repo.listComments(memo.id)).length, 1);
    expect((await repo.watchMemos().first).single.commentCount, 1);
    await expectLater(repo.addComment(memoId: memo.id, content: '  '), throwsException);
  });

  test('markRead flips readByMe', () async {
    final repo = MockMemoRepository();
    final memo = await repo.addMemo(content: '방문', tags: const []);
    expect(memo.readByMe, isFalse);
    await repo.markRead([memo.id]);
    expect((await repo.watchMemos().first).single.readByMe, isTrue);
  });

  test('Memo.fromJson reads comment/read fields', () {
    final memo = Memo.fromJson({
      'id': 'm1',
      'orgId': 'o1',
      'authorType': 'institute',
      'authorName': '수산질병관리원 · 김철수',
      'authorMemberId': 'member-1',
      'content': '내용',
      'tags': <String>[],
      'createdAt': '2026-10-06T00:00:00Z',
      'commentCount': 3,
      'readCount': 2,
      'readByMe': true,
    });
    expect(memo.authorMemberId, 'member-1');
    expect(memo.commentCount, 3);
    expect(memo.readCount, 2);
    expect(memo.readByMe, isTrue);
  });

  test('DigestSettings round-trips the server JSON', () {
    final s = DigestSettings.fromJson({'dailyEnabled': false, 'dailyTime': '07:05', 'weeklyEnabled': true});
    expect(s.dailyEnabled, isFalse);
    expect(s.dailyTime, const TimeOfDay(hour: 7, minute: 5));
    expect(s.toJson(), {'dailyEnabled': false, 'dailyTime': '07:05', 'weeklyEnabled': true});
  });
}
