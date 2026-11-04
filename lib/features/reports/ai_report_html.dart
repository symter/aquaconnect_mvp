import 'dart:convert';
import 'dart:math' as math;

import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../../data/models/ai_report.dart';
import 'ai_report_document.dart';

/// The AI 리포트 as a standalone A4 HTML page — what 인쇄 / PDF로 저장 prints
/// and what the farm sees from its share link. Same form as
/// [AiReportDocument] (기본 정보 → sections with their charts → 전문가 최종
/// 의견); the evidence check's 〔확인 필요: …〕 notes are staff-only and left
/// out.
String buildAiReportHtml(AiReport r, {required String farmName, required String orgName}) {
  final m = r.meta;
  final sections = parseAiReportBody(r.body ?? '');
  final titles = AiReportDocument.titlesFor(r);
  final structured = m != null && titles.every((t) => sections.any((s) => s.title == t));
  final fmt = DateFormat('yyyy년 M월 d일');
  final b = StringBuffer();

  b.write('<!doctype html><html lang="ko"><head><meta charset="utf-8">'
      '<meta name="viewport" content="width=device-width,initial-scale=1">'
      '<title>${_e(r.isAgency ? '관리원 종합 리포트' : '$farmName 관리 리포트')}</title>'
      '<link rel="preconnect" href="https://fonts.googleapis.com">'
      '<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@400;500;700;900&display=swap" rel="stylesheet">'
      '<style>$_css</style></head><body><article class="doc">');
  if (r.isDraft) b.write('<p class="draft">초안 — 전문가 확인 전입니다. 확정 후 최종본으로 인쇄하세요.</p>');
  b.write('<h1>${r.isAgency ? '관리원 종합 리포트' : '양식장 관리 리포트'}</h1>');

  final recordPeriod = m?['recordPeriod'] as Map<String, dynamic>?;
  final authors = ((m?['authors'] as List<dynamic>?) ?? []).cast<String>();
  b.write(_meta(r.isAgency
      ? [
          ('수산질병관리원', orgName),
          ('대상 기간', '${r.periodStart} ~ ${r.periodEnd}'),
          if (m != null) ('관리 양식장', '${m['farmCount']}곳 (이 기간 메모가 있는 양식장 ${m['activeFarmCount']}곳)'),
          ('입력 범위', '메모 ${r.memoCount}건'),
          ('리포트 생성일', fmt.format(r.createdAt.toLocal())),
          if (r.confirmedAt != null) ('확정일', fmt.format(r.confirmedAt!.toLocal())),
        ]
      : [
          ('양식장', farmName),
          ('대상 기간', '${r.periodStart} ~ ${r.periodEnd}'),
          ('수산질병관리원', orgName),
          ('담당', r.confirmedByName ?? (authors.isNotEmpty ? authors.join(', ') : '(확정 시 표시)')),
          if (recordPeriod != null) ('메모 기록 기간', '${recordPeriod['first']} ~ ${recordPeriod['last']}'),
          ('입력 범위', '메모 ${r.memoCount}건${r.commentCount > 0 ? ' · 연결 댓글 ${r.commentCount}개 포함' : ''}'),
          ('리포트 생성일', fmt.format(r.createdAt.toLocal())),
          if (r.sentAt != null && r.isSent) ('발송일', fmt.format(r.sentAt!.toLocal())),
        ]));

  for (final s in sections) {
    b.write('<section><h2>${_e(s.title)}</h2><ul class="items">');
    for (final line in s.lines) {
      b.write('<li>${_item(line)}</li>');
    }
    b.write('</ul>');
    if (structured) b.write(r.isAgency ? _agencyExtras(s.title, r, m) : _farmExtras(s.title, r, m));
    b.write('</section>');
  }
  if (structured && r.isAgency) b.write(_agencyTable(m));

  b.write('<section><h2 class="plain">전문가 최종 의견</h2>');
  b.write(r.finalOpinion.isNotEmpty ? '<p class="opinion">${_e(r.finalOpinion).replaceAll('\n', '<br>')}</p>' : '<p class="muted">작성된 최종 의견이 없습니다.</p>');
  if (r.isConfirmed) {
    b.write(_meta([
      ('승인', r.confirmedByName ?? ''),
      ('승인일', r.confirmedAt == null ? '-' : fmt.format(r.confirmedAt!.toLocal())),
      if (r.version > 0) ('리포트 판', '제${r.version}판'),
      ('전문가 수정', r.editedSections.isEmpty ? 'AI 초안을 수정 없이 승인함' : '${r.editedSections.join(', ')} 섹션을 전문가가 수정함'),
    ]));
  } else {
    b.write('<p class="muted">아직 전문가가 확정하지 않은 초안입니다. 위 내용은 AI 초안이며 최종 판단이 아닙니다.</p>');
  }
  b.write('</section><p class="foot">${_e(aiReportSourceFooter)}</p>');
  b.write('</article></body></html>');
  return b.toString();
}

const _css = '''
:root{--ink:#1c2733;--sub:#5d6b7a;--line:#dde4ea;--brand:#1f5fa8;--bg:#eef2f5;--tint:#f4f7f9;--warn:#fdf1dc;--warnInk:#7a5410}
*{box-sizing:border-box}
html,body{margin:0}
body{background:var(--bg);color:var(--ink);font-family:"Noto Sans KR",system-ui,sans-serif;font-size:13px;line-height:1.6;-webkit-print-color-adjust:exact;print-color-adjust:exact}
.doc{max-width:760px;margin:12px auto;overflow-wrap:anywhere;background:#fff;padding:28px 30px 22px;border:1px solid var(--line);border-radius:12px}
h1{text-align:center;font-size:22px;font-weight:900;margin:4px 0 18px}
h2{color:var(--brand);font-size:16px;font-weight:900;border-bottom:2px solid var(--brand);padding-bottom:5px;margin:26px 0 10px}
h2.plain{color:var(--ink);border:0}
h4{font-size:13px;margin:14px 0 6px;color:var(--sub)}
dl.meta{display:grid;grid-template-columns:120px 1fr;gap:5px 10px;margin:0}
dl.meta dt{color:var(--sub)}dl.meta dd{margin:0}
ul.items{margin:0;padding-left:20px}ul.items li{margin:0 0 7px}
.cite{color:#8a96a3}
.warnq{color:#b3261e;font-weight:700}
.tiles{display:grid;grid-template-columns:repeat(auto-fill,minmax(118px,1fr));gap:12px;margin:12px 0 6px}
.tile b{display:block;font-size:20px;font-weight:900}
.tile span{font-size:11.5px;color:var(--sub)}
.dot{display:inline-block;width:7px;height:7px;border-radius:50%;margin-right:4px;vertical-align:middle}
.rows{margin:6px 0}.rows div{display:flex;justify-content:space-between;padding:5px 4px;border-left:3px solid #4a6785;padding-left:9px;margin:3px 0}
.rows div span:last-child{color:var(--sub)}
svg.chart{width:100%;height:auto;display:block;margin-top:10px}
.legend{display:flex;flex-wrap:wrap;gap:4px 14px;font-size:11px;color:var(--sub);margin-top:4px}
.box{background:var(--tint);border-left:3px solid #8a96a3;border-radius:6px;padding:12px 14px;margin-top:12px}
.box b{display:block;margin-bottom:8px}
.open{background:var(--tint);border-radius:8px;padding:10px 12px;margin:6px 0}
.chip{display:inline-block;background:var(--warn);color:var(--warnInk);font-size:11px;font-weight:800;border-radius:6px;padding:1px 7px;margin-bottom:4px}
.muted{color:#8a96a3}
.hbars{list-style:none;margin:8px 0 4px;padding:0;display:grid;grid-template-columns:110px 1fr auto;gap:5px 8px;align-items:center;font-size:12px}
.hbars li{display:contents}
.hbars .n{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.hbars .t{height:14px;background:#eef2f5;border-radius:4px;display:flex;overflow:hidden}
.hbars .t i{display:block;height:100%}
.hbars .t i:last-child{border-radius:0 4px 4px 0}
.hbars .v{min-width:44px;text-align:right;color:var(--sub)}
details.groups{background:var(--tint);border-radius:8px;padding:8px 12px;margin-top:12px}
details.groups summary{font-weight:800;cursor:pointer}
details.groups h5{margin:10px 0 4px;font-size:12.5px}
details.groups ul{list-style:none;margin:0;padding:0}
details.groups li{margin:3px 0;font-size:12px}
details.groups .d{display:inline-block;width:40px;color:#8a96a3}
.draft{background:var(--warn);color:var(--warnInk);font-weight:700;border-radius:8px;padding:8px 12px}
.opinion{white-space:normal}
table.grid{border-collapse:collapse;font-size:12px;width:100%}
table.grid th,table.grid td{border-bottom:1px solid var(--line);padding:5px 6px;text-align:left}
table.grid td.n,table.grid th.n{text-align:right}
.matrix td{text-align:center;min-width:34px;border-radius:4px}
.foot{font-size:11px;color:#8a96a3;border-top:1px solid var(--line);padding-top:10px;margin-top:22px}
@media (max-width:520px){.doc{margin:0;border:0;border-radius:0;padding:18px 14px 16px}h1{font-size:19px}dl.meta{grid-template-columns:92px 1fr}.tiles{grid-template-columns:repeat(auto-fill,minmax(96px,1fr));gap:10px}.tile b{font-size:17px}}
@page{size:A4;margin:14mm}
@media print{body{background:#fff}.doc{border:0;margin:0;max-width:none;padding:0}section{break-inside:auto}h2{break-after:avoid}svg.chart,.tiles,.box,.open{break-inside:avoid}}
''';

final _num = NumberFormat.decimalPattern('ko_KR');
String _e(String s) => const HtmlEscape(HtmlEscapeMode.element).convert(s);
String _range(int min, int max) => min == max ? '${_num.format(min)}마리' : '${_num.format(min)}~${_num.format(max)}마리';
String _md(String date) => '${int.parse(date.substring(5, 7))}월 ${int.parse(date.substring(8, 10))}일';
DateTime _day(String date) => DateTime.utc(int.parse(date.substring(0, 4)), int.parse(date.substring(5, 7)), int.parse(date.substring(8, 10)));
String _hex(int argb) => '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
String _kind(String k) => _hex(kindColor(k).toARGB32());
String _numStr(Object? v) => v is double && v == v.roundToDouble() ? v.toInt().toString() : '$v';

String _meta(List<(String, String)> rows) =>
    '<dl class="meta">${rows.map((r) => '<dt>${_e(r.$1)}</dt><dd>${_e(r.$2)}</dd>').join()}</dl>';

final _tagRe = RegExp(r'〔([^〕]*)〕');

/// One "- 항목" line: 〔근거〕 muted, inline 〔… 확인 필요〕 red, the evidence
/// check's 〔확인 필요: …〕 notes dropped.
String _item(String line) {
  final text = line.startsWith('- ') ? line.substring(2) : line;
  final out = StringBuffer();
  var last = 0;
  for (final m in _tagRe.allMatches(text)) {
    out.write(_e(text.substring(last, m.start)));
    last = m.end;
    final tag = m.group(1)!;
    if (tag.startsWith('확인 필요:')) continue;
    if (tag.startsWith('근거')) {
      out.write('<span class="cite">〔${_e(tag)}〕</span>');
    } else if (tag.contains('확인 필요')) {
      out.write('<span class="warnq">〔${_e(tag)}〕</span>');
    } else {
      out.write('〔${_e(tag)}〕');
    }
  }
  out.write(_e(text.substring(last)));
  return out.toString();
}

String _tiles(List<(String, String, String?)> items) =>
    '<div class="tiles">${items.map((t) => '<div class="tile"><b>${_e(t.$2)}</b><span>${t.$3 == null ? '' : '<i class="dot" style="background:${t.$3}"></i>'}${_e(t.$1)}</span></div>').join()}</div>';

String _rows(List<(String, String)> rows) =>
    '<div class="rows">${rows.map((r) => '<div><span>${_e(r.$1)}</span><span>${_e(r.$2)}</span></div>').join()}</div>';

String _legend(List<(String, String, bool)> items) =>
    '<div class="legend">${items.map((i) => '<span><i class="dot" style="background:${i.$2};${i.$3 ? '' : 'border-radius:2px;width:12px'}"></i>${_e(i.$1)}</span>').join()}</div>';

String _hbars(List<HBar> bars, String color, {String? light, String? emptyLabel}) {
  final top = bars.fold<num>(1, (m, b) => math.max(m, b.total));
  String pct(num v) => (v / top * 100).toStringAsFixed(1);
  return '<ul class="hbars">${bars.map((b) {
    final track = b.total == 0 && emptyLabel != null
        ? '<span class="muted">${_e(emptyLabel)}</span>'
        : '<span class="t">${b.solid > 0 ? '<i style="width:${pct(b.solid)}%;background:$color"></i>' : ''}'
            '${b.total > b.solid ? '<i style="width:${pct(b.total - b.solid)}%;background:${light ?? color}"></i>' : ''}</span>';
    return '<li><span class="n">${_e(b.name)}</span>$track<span class="v">${_e(b.label)}</span></li>';
  }).join()}</ul>';
}

String _memoGroups(List<Map<String, dynamic>> groups) {
  final b = StringBuffer('<details class="groups"><summary>원문 메모 보기 (주제별)</summary>');
  for (final g in groups) {
    final items = (g['items'] as List<dynamic>).cast<Map<String, dynamic>>();
    b.write('<h5>${_e('${g['topic']}')} <span class="muted">${items.length}건</span></h5><ul>');
    for (final it in items) {
      b.write('<li><span class="d">${_e((it['date'] as String).substring(5))}</span>${_e('${it['text']}')}'
          '${it['death'] != null ? ' <span class="chip">${_e('폐사 ${it['death']}')}</span>' : ''}'
          '${it['status'] != null ? ' <span class="chip">${_e('${it['status']}')}</span>' : ''}</li>');
    }
    b.write('</ul>');
  }
  b.write('</details>');
  return b.toString();
}

String _openItems(List<Map<String, dynamic>> items) {
  if (items.isEmpty) return '<p class="muted">후속 확인이 필요하다고 적힌 기록이 없습니다.</p>';
  return items
      .map((o) =>
          '<div class="open"><span class="chip">${_e('${o['status']}')}</span><div>${o['farm'] != null ? '<b>${_e('${o['farm']}')}</b> · ' : ''}${_e('${(o['date'] as String).substring(5)} ${o['topic']} — ${o['text']}')}</div></div>')
      .join();
}

/// x position of a day across the report period.
double Function(DateTime) _xOf(DateTime from, DateTime to, double left, double right, double width) {
  final span = math.max(1, to.difference(from).inDays);
  return (d) => left + d.difference(from).inDays / span * (width - left - right);
}

String _axis(DateTime from, DateTime to, double Function(DateTime) x, double y) {
  String label(DateTime d) => '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  final days = to.difference(from).inDays + 1;
  final mid = from.add(Duration(days: (days - 1) ~/ 2));
  return [
    '<text x="${x(from)}" y="$y" font-size="11" fill="#5d6b7a">${label(from)}</text>',
    if (days > 2) '<text x="${x(mid)}" y="$y" font-size="11" fill="#5d6b7a" text-anchor="middle">${label(mid)}</text>',
    '<text x="${x(to)}" y="$y" font-size="11" fill="#5d6b7a" text-anchor="end">${label(to)}</text>',
  ].join();
}

String _timeline(List<Map<String, dynamic>> events, String from, String to) {
  final kinds = {for (final e in events) e['kind'] as String};
  final lanes = [...reportKindOrder.where(kinds.contains), ...kinds.where((k) => !reportKindOrder.contains(k))];
  const w = 640.0, lane = 26.0;
  final h = 8 + lanes.length * lane + 24;
  final f = _day(from), t = _day(to);
  final x = _xOf(f, t, 40, 10, w);
  final b = StringBuffer('<svg class="chart" viewBox="0 0 $w $h" role="img" aria-label="기록 타임라인">');
  for (var n = 0; n < lanes.length; n++) {
    final k = lanes[n];
    final y = 20 + n * lane;
    b.write('<line x1="40" x2="${w - 10}" y1="$y" y2="$y" stroke="#e3e9ef"/>');
    b.write('<text x="34" y="${y + 4}" font-size="11" text-anchor="end" fill="#5d6b7a">${_e(k)}</text>');
    final byDay = <DateTime, int>{};
    for (final e in events.where((e) => e['kind'] == k)) {
      final d = _day(e['date'] as String);
      byDay[d] = (byDay[d] ?? 0) + 1;
    }
    for (final MapEntry(key: d, value: c) in byDay.entries) {
      b.write('<circle cx="${x(d)}" cy="$y" r="${c > 1 ? 8 : 6}" fill="${_kind(k)}" stroke="#fff" stroke-width="2"/>');
      if (c > 1) b.write('<text x="${x(d)}" y="${y + 4}" font-size="10" font-weight="700" text-anchor="middle" fill="#fff">$c</text>');
    }
  }
  b.write(_axis(f, t, x, h - 6));
  b.write('</svg>');
  b.write(_legend([for (final k in lanes) (k, _kind(k), true)]));
  return b.toString();
}

String _deathChart(List<Map<String, dynamic>> byDay, String from, String to) {
  const w = 640.0, h = 210.0, top = 22.0, bottom = 26.0;
  final f = _day(from), t = _day(to);
  final x = _xOf(f, t, 38, 10, w);
  final peak = byDay.fold<int>(1, (m, d) => math.max(m, d['max'] as int));
  final step = math.max(1, (peak / 4).ceil());
  final hi = step * 4;
  double y(num v) => top + (hi - v) * (h - top - bottom) / hi;
  final days = t.difference(f).inDays + 1;
  final bw = ((w - 48) / days * 0.7).clamp(4.0, 16.0);
  final death = _kind('폐사');
  final b = StringBuffer('<svg class="chart" viewBox="0 0 $w $h" role="img" aria-label="날짜별 폐사 마리수">');
  for (var i = 0; i <= 4; i++) {
    final v = step * i;
    b.write('<line x1="38" x2="${w - 10}" y1="${y(v)}" y2="${y(v)}" stroke="#e3e9ef"/>');
    b.write('<text x="32" y="${y(v) + 4}" font-size="11" text-anchor="end" fill="#5d6b7a">${_num.format(v)}</text>');
  }
  var hasRange = false, hasUnknown = false;
  for (final d in byDay) {
    final cx = x(_day(d['date'] as String));
    final min = d['min'] as int, max = d['max'] as int, unknown = d['unknown'] as int;
    if (max > min) {
      hasRange = true;
      b.write('<rect x="${cx - bw / 2}" y="${y(max)}" width="$bw" height="${y(min) - y(max)}" rx="3" fill="#f6c9b6"/>');
    }
    if (min > 0) b.write('<rect x="${cx - bw / 2}" y="${y(min)}" width="$bw" height="${y(0) - y(min)}" rx="3" fill="$death"/>');
    if (max > 0) {
      b.write('<text x="$cx" y="${y(max) - 6}" font-size="11" font-weight="700" text-anchor="middle" fill="#1c2733">${max > min ? '$min~$max' : '$max'}</text>');
    }
    if (unknown > 0) {
      hasUnknown = true;
      final cy = max > 0 ? y(max) - 24 : y(0) - 11;
      b.write('<circle cx="$cx" cy="$cy" r="8" fill="#fff" stroke="$death" stroke-width="1.5"/>'
          '<text x="$cx" y="${cy + 4}" font-size="10" font-weight="800" text-anchor="middle" fill="$death">?</text>');
    }
  }
  b.write(_axis(f, t, x, h - 6));
  b.write('</svg>');
  b.write(_legend([
    ('확정된 폐사 마리수', death, false),
    if (hasRange) ('범위로 적힌 폐사(최대)', '#f6c9b6', false),
    if (hasUnknown) ('? 수량 미기재 기록', death, true),
  ]));
  return b.toString();
}

/// 일별 수온 SVG — same chart as the app's _TempChart.
String _tempChart(List<Map<String, dynamic>> daily, Map<String, dynamic> temp, List<Map<String, dynamic>> events, String from, String to) {
  const w = 640.0, top = 12.0, plotBottom = 202.0, laneH = 22.0;
  final lanes = reportKindOrder.where((k) => events.any((e) => e['kind'] == k)).toList();
  final h = plotBottom + 24 + lanes.length * laneH;
  final f = _day(from), t = _day(to);
  final x = _xOf(f, t, 40, 10, w);
  final high = (temp['highThreshold'] as num).toDouble(), low = (temp['lowThreshold'] as num).toDouble();
  double v(Map<String, dynamic> d, String k) => (d[k] as num).toDouble();
  final (lo, hi, step) = tempRange([for (final d in daily) ...[v(d, 'min'), v(d, 'max')], high, low]);
  double y(double c) => top + (hi - c) * (plotBottom - top) / (hi - lo);
  String px(double n) => n.toStringAsFixed(1);
  final b = StringBuffer('<svg class="chart" viewBox="0 0 $w $h" role="img" aria-label="일별 수온 그래프">');
  for (var c = lo; c <= hi + 1e-9; c += step) {
    b.write('<line x1="40" x2="${w - 10}" y1="${px(y(c))}" y2="${px(y(c))}" stroke="#e3e9ef"/>');
    b.write('<text x="34" y="${px(y(c) + 4)}" font-size="11" text-anchor="end" fill="#5d6b7a">${fmtTemp(c)}℃</text>');
  }
  for (final (at, color, label) in [(high, '#c98500', '고수온 기준'), (low, '#185fa5', '저수온 기준')]) {
    b.write('<line x1="40" x2="${w - 10}" y1="${px(y(at))}" y2="${px(y(at))}" stroke="$color" stroke-dasharray="5 4"/>');
    b.write('<text x="${w - 10}" y="${px(y(at) - 4)}" font-size="11" text-anchor="end" fill="$color">$label ${fmtTemp(at)}℃</text>');
  }
  final runs = <List<Map<String, dynamic>>>[];
  for (final d in daily) {
    final day = _day(d['date'] as String);
    if (runs.isEmpty || day.difference(_day(runs.last.last['date'] as String)).inDays > 1) runs.add([]);
    runs.last.add(d);
  }
  for (final run in runs) {
    double xd(Map<String, dynamic> d) => x(_day(d['date'] as String));
    if (run.length == 1) {
      final d = run.first;
      b.write('<line x1="${px(xd(d))}" x2="${px(xd(d))}" y1="${px(y(v(d, 'min')))}" y2="${px(y(v(d, 'max')))}" stroke="#52606d" stroke-opacity=".35" stroke-width="4"/>');
      b.write('<circle cx="${px(xd(d))}" cy="${px(y(v(d, 'avg')))}" r="3" fill="#3b4a5a"/>');
      continue;
    }
    final band = [
      for (final d in run) '${px(xd(d))},${px(y(v(d, 'max')))}',
      for (final d in run.reversed) '${px(xd(d))},${px(y(v(d, 'min')))}',
    ];
    b.write('<path d="M${band.join('L')}Z" fill="#52606d" opacity=".12"/>');
    b.write('<path d="M${[for (final d in run) '${px(xd(d))},${px(y(v(d, 'avg')))}'].join('L')}" fill="none" stroke="#3b4a5a" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>');
  }
  b.write(_axis(f, t, x, plotBottom + 16));
  for (var n = 0; n < lanes.length; n++) {
    final k = lanes[n];
    final ly = plotBottom + 34 + n * laneH;
    b.write('<line x1="40" x2="${w - 10}" y1="$ly" y2="$ly" stroke="#e3e9ef"/>');
    b.write('<text x="34" y="${ly + 4}" font-size="11" text-anchor="end" fill="#5d6b7a">${_e(k)}</text>');
    for (final date in {for (final e in events.where((e) => e['kind'] == k)) e['date'] as String}) {
      b.write('<circle cx="${px(x(_day(date)))}" cy="$ly" r="5" fill="${_kind(k)}" stroke="#fff" stroke-width="2"/>');
    }
  }
  b.write('</svg>');
  b.write(_legend([
    ('일 평균 수온', '#3b4a5a', false),
    ('일 최저~최고', '#c5cbd1', false),
    for (final k in lanes) ('$k 기록일', _kind(k), true),
  ]));
  return b.toString();
}

/// 관측소별 일 평균 수온 SVG — same chart as the app's _StationLinesChart.
String _stationLines(List<Map<String, dynamic>> stations, String from, String to) {
  const w = 640.0, top = 12.0, plotBottom = 210.0, h = plotBottom + 24;
  final f = _day(from), t = _day(to);
  final x = _xOf(f, t, 40, 10, w);
  final (high, low) = stationThresholds(stations);
  List<Map<String, dynamic>> daily(Map<String, dynamic> st) => ((st['daily'] as List<dynamic>?) ?? const []).cast<Map<String, dynamic>>();
  final (lo, hi, step) = tempRange([for (final st in stations) for (final d in daily(st)) d['avg'] as num, high, low]);
  double y(double c) => top + (hi - c) * (plotBottom - top) / (hi - lo);
  String px(double n) => n.toStringAsFixed(1);
  final b = StringBuffer('<svg class="chart" viewBox="0 0 $w $h" role="img" aria-label="관측소별 일 평균 수온 그래프">');
  for (var c = lo; c <= hi + 1e-9; c += step) {
    b.write('<line x1="40" x2="${w - 10}" y1="${px(y(c))}" y2="${px(y(c))}" stroke="#e3e9ef"/>');
    b.write('<text x="34" y="${px(y(c) + 4)}" font-size="11" text-anchor="end" fill="#5d6b7a">${fmtTemp(c)}℃</text>');
  }
  for (final (at, color, label) in [(high, '#c98500', '고수온 기준'), (low, '#185fa5', '저수온 기준')]) {
    b.write('<line x1="40" x2="${w - 10}" y1="${px(y(at))}" y2="${px(y(at))}" stroke="$color" stroke-dasharray="5 4"/>');
    b.write('<text x="${w - 10}" y="${px(y(at) - 4)}" font-size="11" text-anchor="end" fill="$color">$label ${fmtTemp(at)}℃</text>');
  }
  for (var k = 0; k < stations.length; k++) {
    final color = _hex(stationLineColors[k].toARGB32());
    final runs = <List<Map<String, dynamic>>>[];
    for (final d in daily(stations[k])) {
      final day = _day(d['date'] as String);
      if (runs.isEmpty || day.difference(_day(runs.last.last['date'] as String)).inDays > 1) runs.add([]);
      runs.last.add(d);
    }
    for (final run in runs) {
      String at(Map<String, dynamic> d) => '${px(x(_day(d['date'] as String)))},${px(y((d['avg'] as num).toDouble()))}';
      if (run.length == 1) {
        final p = at(run.first).split(',');
        b.write('<circle cx="${p[0]}" cy="${p[1]}" r="3.5" fill="$color"/>');
        continue;
      }
      b.write('<path d="M${[for (final d in run) at(d)].join('L')}" fill="none" stroke="$color" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>');
    }
  }
  b.write(_axis(f, t, x, plotBottom + 16));
  b.write('</svg>');
  b.write(_legend([
    for (var k = 0; k < stations.length; k++) ('${stations[k]['name']} (양식장 ${stations[k]['farms']}곳)', _hex(stationLineColors[k].toARGB32()), false),
  ]));
  return b.toString();
}

String _farmExtras(String title, AiReport r, Map<String, dynamic> m) {
  final an = (m['analysis'] as Map<String, dynamic>?) ?? const {};
  final deaths = (an['deaths'] as Map<String, dynamic>?) ?? const {};
  final open = ((an['open'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();
  final tanks = ((m['tanks'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();
  final events = ((m['events'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();
  final byKind = ((m['memoStats'] as Map<String, dynamic>?)?['byKind'] as Map<String, dynamic>?) ?? const {};
  final topics = ((an['topics'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();
  final groups = ((an['groups'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();
  final deathEvents = deaths['events'] as int? ?? 0;
  final total = an['total'] as int? ?? r.memoCount;
  final topicColor = _hex(0xFF4A6785);
  switch (AiReportDocument.sectionTitles.indexOf(title)) {
    case 0:
      final max = deaths['max'] as int? ?? 0;
      return _tiles([
        ('현장 기록', '$total건', null),
        ('확인된 폐사', max > 0 ? _range(deaths['min'] as int? ?? 0, max) : deathEvents > 0 ? '마리수 미확정' : '없음', _kind('폐사')),
        ('후속 확인 필요', '${open.length}건', null),
        ('언급된 수조', '${tanks.length}개', null),
      ]);
    case 1:
      final kinds = [...reportKindOrder, ...byKind.keys.where((k) => !reportKindOrder.contains(k))];
      return [
        _tiles([for (final k in kinds) (k, '${byKind[k] ?? 0}건', _kind(k))]),
        if (events.isNotEmpty) _timeline(events, r.periodStart, r.periodEnd),
        if (tanks.isNotEmpty) '<h4>수조별 관찰 건수</h4>${_hbars(countBars([for (final t in tanks) ('${t['tank']}번 수조', t['count'] as int)], '건'), topicColor)}',
        if (groups.isNotEmpty) _memoGroups(groups),
      ].join();
    case 2:
      return [
        if (topics.isNotEmpty) _hbars(countBars([for (final t in topics) (t['topic'] as String, t['count'] as int)], '건'), topicColor),
        if (deathEvents > 0) _deathChart(((deaths['byDay'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>(), r.periodStart, r.periodEnd),
      ].join();
    case 3:
      final measurements = ((m['measurements'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();
      final pub = m['publicData'] as Map<String, dynamic>?;
      final station = pub?['station'] as Map<String, dynamic>?;
      final obs = pub?['observation'] as Map<String, dynamic>?;
      final temp = pub?['temp'] as Map<String, dynamic>?;
      final daily = ((pub?['daily'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();
      final red = pub?['redTide'] as Map<String, dynamic>?;
      final redText = switch (red?['status']) {
        'found' => '${red!['reportDate']} 발표 · ${((red['occurrences'] as List<dynamic>?) ?? []).join(', ')} (전국 해역 대상 속보)',
        'none' => '기간 중 발표된 속보 없음',
        _ => '조회 실패 — 사용하지 않음',
      };
      return [
        if (measurements.isNotEmpty)
          '<h4>현장 실측(메모에 적힌 값)</h4><ul class="items">${measurements.map((x) {
            final tanks = ((x['tanks'] as List<dynamic>?) ?? []);
            return '<li>${_e('${_md(x['date'] as String)} ${tanks.isEmpty ? '' : '${tanks.join('·')}번 수조 '}${x['name']} ${_numStr(x['value'])}${x['unit']}')}</li>';
          }).join()}</ul>',
        '<h4>외부 관측(공공데이터)</h4>',
        if (temp != null)
          '${_tiles([for (final (l, v) in tempStatItems(temp)) (l, v, null)])}'
              '${daily.length > 1 ? _tempChart(daily, temp, events, r.periodStart, r.periodEnd) : ''}'
              '<p class="muted">${_e(tempCoverageNote(station?['name'] as String?, temp))}</p>'
              '${obs != null ? '<p class="muted">${_e('작성 시점 실시간 값: ${obs['layer']} ${_numStr(obs['waterTempC'])}℃ (관측 ${obs['observedDate']} ${obs['observedTime']})')}</p>' : ''}'
        else if (obs != null)
          '${_tiles([('${station?['name'] ?? '관측소'} ${obs['layer']} 수온', '${_numStr(obs['waterTempC'])}℃', null)])}<p class="muted">관측 ${_e('${obs['observedDate']} ${obs['observedTime']}')} · 리포트 작성 시점의 실시간 값이며 기간 평균이 아닙니다(이 기간의 수온 이력이 없음).</p>'
        else
          '<p class="muted">외부 관측 수온 자료를 가져오지 못했습니다.</p>',
        if (pub != null)
          '<div class="box"><b>외부 관측 자료(공공데이터) — 양식장 수조 실측값이 아닙니다</b>${_meta([
            ('상태', temp != null || obs != null ? '사용' : '수온 조회 실패 — 사용하지 않음'),
            ('제공 기관', '해양수산부 국립수산과학원'),
            ('데이터', '해양관측 수온(1시간 간격 수집) · 적조 속보'),
            if (station != null) ('관측소', '${station['name']}${station['code'] != null ? ' (${station['code']})' : ''}'),
            if (temp != null) ('수온 자료', '${temp['firstDate']} ~ ${temp['lastDate']} · ${temp['days']}일분 (${temp['layer']})'),
            if (obs != null) ('실시간 관측 시각', '${obs['observedDate']} ${obs['observedTime']}'),
            ('적조 속보', redText),
            if (((pub['notConnected'] as List<dynamic>?) ?? []).isNotEmpty) ('미연동', ((pub['notConnected'] as List<dynamic>?) ?? []).join(', ')),
          ])}</div>',
      ].join();
    case 4:
      final prev = m['prev'] as Map<String, dynamic>?;
      final temp = (m['publicData'] as Map<String, dynamic>?)?['temp'] as Map<String, dynamic>?;
      final hasTemp = temp?['prevAvg'] != null;
      if (prev == null && !hasTemp) return '';
      return _tiles([
        if (prev != null) ('현장 기록 (이전 → 이번 기간)', '${prev['total']} → $total건', null),
        if (prev != null) ('폐사 기록 (이전 → 이번 기간)', '${prev['deathEvents']} → $deathEvents건', _kind('폐사')),
        if (hasTemp) ('외부 관측 평균 수온 (이전 → 이번 기간)', '${fmtTemp(temp!['prevAvg'])} → ${fmtTemp(temp['avg'])}℃', null),
      ]);
    case 5:
      return _openItems(open);
    default:
      return '';
  }
}

String _agencyExtras(String title, AiReport r, Map<String, dynamic> m) {
  final rows = ((m['rows'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();
  final deaths = (m['deathTotals'] as Map<String, dynamic>?) ?? const {};
  final open = ((m['open'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();
  final topics = ((m['topicTotals'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();
  final stations = ((m['stations'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();
  final total = rows.fold<int>(0, (n, x) => n + (x['memos'] as int? ?? 0));
  final max = deaths['max'] as int? ?? 0;
  switch (AiReportDocument.agencySectionTitles.indexOf(title)) {
    case 0:
      return _tiles([
        ('관리 양식장', '${m['farmCount']}곳', null),
        ('관리원 기록', '$total건', null),
        ('확인된 폐사', max > 0 ? _range(deaths['min'] as int? ?? 0, max) : (deaths['events'] as int? ?? 0) > 0 ? '마리수 미확정' : '없음', _kind('폐사')),
        ('후속 확인 필요', '${open.length}건', null),
      ]);
    case 1:
      final order = ((m['topicOrder'] as List<dynamic>?) ?? []).cast<String>();
      final active = rows.where((x) => (x['memos'] as int? ?? 0) > 0).toList();
      final peak = active.fold<int>(1, (p, x) => ((x['topicCounts'] as Map<String, dynamic>?) ?? const {}).values.fold<int>(p, (a, v) => math.max(a, (v as num).toInt())));
      final matrix = StringBuffer('<h4>양식장 × 주제</h4><div style="overflow-x:auto"><table class="grid matrix"><tr><th></th>');
      for (final t in order) {
        matrix.write('<th>${_e(t)}</th>');
      }
      matrix.write('</tr>');
      for (final x in active) {
        matrix.write('<tr><th>${_e('${x['name']}')}</th>');
        for (final t in order) {
          final n = (((x['topicCounts'] as Map<String, dynamic>?) ?? const {})[t] as num?)?.toInt() ?? 0;
          final alpha = n == 0 ? 0 : 0.18 + 0.72 * n / peak;
          matrix.write('<td style="background:rgba(74,103,133,$alpha);color:${alpha > 0.5 ? '#fff' : '#1c2733'}">${n == 0 ? '' : n}</td>');
        }
        matrix.write('</tr>');
      }
      matrix.write('</table></div>');
      return [
        if (topics.isNotEmpty) _hbars(countBars([for (final t in topics) (t['topic'] as String, t['count'] as int)], '건'), _hex(0xFF4A6785)),
        if (active.isNotEmpty) matrix.toString(),
      ].join();
    case 3:
      final bars = deathBars(rows);
      if (bars.isEmpty) return '<p class="muted">폐사가 적힌 기록이 없습니다.</p>';
      final light = _hex(deathLightColor.toARGB32());
      return _hbars(bars, _kind('폐사'), light: light, emptyLabel: '수량 확인된 기록 없음') +
          _legend([
            ('확정된 폐사 마리수', _kind('폐사'), false),
            if (bars.any((b) => b.total > b.solid)) ('범위로 적힌 폐사(최대)', light, false),
          ]);
    case 4:
      if (stations.isEmpty) return '<p class="muted">연결된 관측소가 없습니다.</p>';
      final note = stations.any((st) => st['temp'] != null)
          ? '관측소 일 평균 수온의 기간 요약입니다(서버가 1시간마다 모은 관측값). 이력이 없는 관측소는 작성 시점 실시간 값입니다.'
          : '관측소 값은 리포트 작성 시점의 실시간 값이며 기간 평균이 아닙니다.';
      final highBars = highDayBars(rows);
      final high = highBars == null
          ? ''
          : '<h4>양식장별 고수온 일수</h4>${highBars.any((b) => b.total > 0) ? _hbars(highBars, _hex(tempHighColor.toARGB32())) : '<p class="muted">고수온 기준 이상이었던 양식장이 없습니다.</p>'}';
      final series = stationSeries(stations);
      final chart = series.isEmpty ? '' : '<h4>관측소별 일 평균 수온</h4>${_stationLines(series, r.periodStart, r.periodEnd)}';
      return '${_rows([for (final st in stations) ('${st['name']} (양식장 ${st['farms']}곳)', stationTempLabel(st))])}$high$chart<p class="muted">${_e(note)}</p>';
    case 5:
      return _openItems(open);
    default:
      return '';
  }
}

String _agencyTable(Map<String, dynamic> m) {
  final rows = ((m['rows'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();
  if (rows.isEmpty) return '';
  final b = StringBuffer('<section><h2>양식장별 현황 표</h2><div style="overflow-x:auto"><table class="grid"><tr>'
      '<th>양식장</th><th>지역</th><th class="n">메모</th><th class="n">방문</th><th class="n">폐사</th><th class="n">접종</th><th>관측소</th><th class="n">기간 평균 수온</th><th class="n">고수온 일수</th></tr>');
  for (final x in rows) {
    final deaths = (x['deathsMax'] as int? ?? 0) > 0
        ? _range(x['deathsMin'] as int? ?? 0, x['deathsMax'] as int)
        : (x['deaths'] as int? ?? 0) > 0
            ? '미확정'
            : '0';
    b.write('<tr><td>${_e('${x['name']}')}</td><td>${_e((x['region'] as String?)?.isNotEmpty == true ? x['region'] as String : '-')}</td>'
        '<td class="n">${x['memos']}</td><td class="n">${x['visits']}</td><td class="n">${_e(deaths)}</td><td class="n">${x['vaccinations']}</td>'
        '<td>${_e('${x['station'] ?? '-'}')}</td><td class="n">${_e(farmRowTempLabel(x))}</td><td class="n">${x['highDays'] == null ? '-' : '${x['highDays']}일'}</td></tr>');
  }
  b.write('</table></div></section>');
  return b.toString();
}
