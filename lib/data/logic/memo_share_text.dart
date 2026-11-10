import 'package:intl/intl.dart';

import '../models/memo.dart';

/// 메모 공유용 1차 가공. A field memo is free text written in a hurry —
/// one long line, "- " / "1)" bullets, @호출, '할일:' markers. These turn it
/// into tidy messages for two audiences:
///  - [farmShareText]: a polite 안내문 for the farm (카카오톡·문자), with
///    staff-only bits removed. The member edits it before sending.
///  - [internalShareText]: a summary for colleagues, ending with a link that
///    opens the memo in the app.

/// The memo body as clean one-item-per-line points.
/// [forFarm] drops staff-only markers (@호출, 할일:, #태그).
List<String> memoPoints(String content, {bool forFarm = false}) {
  var text = content.replaceAll('\r\n', '\n');
  if (forFarm) {
    text = text
        .replaceAllMapped(RegExp(r'(^|\s)[@#][^\s@#]+', multiLine: true), (m) => m[1]!)
        .replaceAll(RegExp(r'할\s*일\s*[:：]\s*'), '');
  }
  final points = <String>[];
  for (var line in text.split('\n')) {
    line = line.trim();
    if (line.isEmpty) continue;
    // A single long line of sentences reads better split up: break after
    // a sentence end (". ", "다. ", "함. ", "?" "!") followed by more text.
    final sentences = line.split(RegExp(r'(?<=[.!?。])\s+(?=\S)'));
    for (var s in sentences) {
      s = s
          .replaceFirst(RegExp(r'^([-*·•▶▷■□◦]|\d{1,2}[.)]|[①-⑳]|\(\d{1,2}\))\s*'), '')
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .trim();
      if (s.isEmpty || RegExp(r'^[.,·\-]+$').hasMatch(s)) continue;
      points.add(s);
    }
  }
  return points;
}

String _bullets(List<String> points) => points.map((p) => '• $p').join('\n');

String _dateLabel(DateTime at) => DateFormat('M월 d일(E)', 'ko_KR').format(at.toLocal());

/// "푸른바다 양식장" → "푸른바다 양식장 대표님"; no farm → "대표님".
String _addressee(Memo memo) => memo.farmName == null ? '대표님' : '${memo.farmName} 대표님';

String farmShareText({
  required Memo memo,
  required String orgName,
  required String senderName,
  String? senderPhone,
}) {
  final points = memoPoints(memo.content, forFarm: true);
  final contact = [senderName, if (senderPhone != null && senderPhone.trim().isNotEmpty) senderPhone.trim()].join(' ');
  return [
    '[$orgName] 현장 점검 안내',
    '',
    '${_addressee(memo)}, 안녕하세요.',
    '${_dateLabel(memo.createdAt)} 현장 점검 내용을 정리해 드립니다.',
    '',
    '■ 점검 내용',
    if (points.isEmpty) '• (내용을 입력해 주세요)' else _bullets(points),
    if (memo.photoCount > 0) ...['', '※ 현장 사진은 따로 보내드립니다.'],
    '',
    '궁금하신 점은 편하게 연락 주세요.',
    '담당 $contact',
  ].join('\n');
}

/// Opens the memo straight into 메모 상세 (`/memo?memo=<id>&detail=1`);
/// signing in first keeps the target (router `from=`).
String memoDeepLink(String memoId, {required String origin}) => '$origin/#/memo?memo=$memoId&detail=1';

String internalShareText({required Memo memo, required String link}) {
  final points = memoPoints(memo.content);
  final when = DateFormat('M/d(E) HH:mm', 'ko_KR').format(memo.createdAt.toLocal());
  final tags = memo.tags.where((t) => !t.startsWith('담당:')).toList();
  final status = memo.isDone
      ? '완료${memo.doneByName == null || memo.doneByName!.isEmpty ? '' : ' (${memo.doneByName})'}'
      : (memo.isTask || memo.mentionedMe ? '진행 중' : null);
  return [
    '[현장 메모] ${memo.farmLabel} · $when',
    [
      '작성 ${memo.authorName}',
      if (memo.assigneeName != null) '담당 ${memo.assigneeName}',
      ?status,
    ].join(' · '),
    if (tags.isNotEmpty) '태그 ${tags.join(', ')}',
    '',
    if (points.isEmpty) memo.content.trim() else _bullets(points),
    if (memo.photoCount > 0 || memo.commentCount > 0)
      [
        if (memo.photoCount > 0) '사진 ${memo.photoCount}장',
        if (memo.commentCount > 0) '댓글 ${memo.commentCount}개',
      ].join(' · '),
    '',
    '▶ 메모 바로 보기',
    link,
  ].join('\n');
}
