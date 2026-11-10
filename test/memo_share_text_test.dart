import 'package:aquaconnect_mvp/data/logic/memo_share_text.dart';
import 'package:aquaconnect_mvp/data/models/memo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Memo _memo(String content, {List<String> tags = const [], int photos = 0}) => Memo(
      id: 'm1',
      orgId: 'o1',
      authorType: MemoAuthorType.institute,
      authorName: '해강수산질병관리원 · 김민재',
      content: content,
      tags: tags,
      createdAt: DateTime(2026, 11, 10, 14, 30),
      farmId: 'f1',
      farmName: '푸른바다 양식장',
      photoCount: photos,
    );

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  test('splits sentences and bullet markers into points', () {
    expect(
      memoPoints('- 2번 수조 섭이 저하. 체표 출혈 일부 관찰.\n1) 병성감정 의뢰함'),
      ['2번 수조 섭이 저하.', '체표 출혈 일부 관찰.', '병성감정 의뢰함'],
    );
  });

  test('farm points drop @호출, #태그 and 할일:', () {
    expect(
      memoPoints('@이영희 2번 수조 확인 부탁 #긴급\n할일: 다음 주 재방문', forFarm: true),
      ['2번 수조 확인 부탁', '다음 주 재방문'],
    );
  });

  test('farm message has greeting, points and contact', () {
    final text = farmShareText(
      memo: _memo('수온 23.5도, DO 5.8 측정. 에어 공급 늘림.', photos: 2),
      orgName: '해강수산질병관리원',
      senderName: '김민재',
      senderPhone: '010-1234-5678',
    );
    expect(text, startsWith('[해강수산질병관리원] 현장 점검 안내\n\n푸른바다 양식장 대표님, 안녕하세요.\n11월 10일(화) 현장 점검 내용'));
    expect(text, contains('• 수온 23.5도, DO 5.8 측정.\n• 에어 공급 늘림.'));
    expect(text, contains('※ 현장 사진은 따로 보내드립니다.'));
    expect(text, endsWith('담당 김민재 010-1234-5678'));
  });

  test('internal message ends with the memo link', () {
    final link = memoDeepLink('m1', origin: 'https://app.example');
    final text = internalShareText(memo: _memo('@이영희 확인 부탁', tags: ['방문', '담당:이영희']), link: link);
    expect(link, 'https://app.example/#/memo?memo=m1&detail=1');
    expect(text, startsWith('[현장 메모] 푸른바다 양식장 · 11/10(화) 14:30\n작성 해강수산질병관리원 · 김민재 · 담당 이영희 · 진행 중\n태그 방문'));
    expect(text, contains('• @이영희 확인 부탁'));
    expect(text, endsWith('▶ 메모 바로 보기\n$link'));
  });
}
