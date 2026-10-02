import 'dart:math' as math;

import 'package:intl/intl.dart';

import '../../data/models/farm_monthly_report.dart';

/// [FarmMonthlyReport] → A4 세로 여러 쪽짜리 HTML (`양식장_관리리포트` 양식).
///
/// 화면 폭에 맞춰 페이지를 축소해 보여 주고, 인쇄하면 A4 한 장에 한 쪽씩
/// 나와 그대로 PDF로 저장된다. 데이터가 없는 구역(해양환경·수조·기록 표)은
/// 빠지고, 두 번째 쪽은 해양환경·수조 데이터가 모두 없으면 생략된다.
String buildFarmReportHtml(FarmMonthlyReport r) {
  final pages = <String>[_page1(r), if (r.seaTemps.isNotEmpty || r.tanks.isNotEmpty) _page2(r), _page3(r)];
  final footLeft = r.isMonthly
      ? '${_e(r.orgName)} · ${_e(r.farmName)} · ${r.year}년 ${r.month}월 관리 리포트'
      : '${_e(r.orgName)} · ${_e(r.farmName)} · 관리 리포트';
  final body = [
    for (var i = 0; i < pages.length; i++)
      '<div class="page">${pages[i]}'
          '<div class="pfoot"><span>$footLeft</span><span>${i + 1} / ${pages.length}</span></div></div>',
  ].join('\n');

  return '''<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${_e(r.title)}</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@400;500;700&family=Noto+Serif+KR:wght@700&display=swap" rel="stylesheet">
<style>$_css</style>
</head>
<body>
<div class="pages" id="pages">
$body
</div>
<script>
// 휴대폰 화면 폭에 맞춰 페이지 축소, 인쇄할 때는 원래 크기로.
const pages=document.getElementById('pages');
function fit(){pages.style.zoom=Math.min(1,(window.innerWidth-16)/794);}
fit();window.addEventListener('resize',fit);
window.addEventListener('beforeprint',()=>pages.style.zoom=1);
window.addEventListener('afterprint',fit);
</script>
</body>
</html>''';
}

// ───────────────────────── 1쪽: 상태·소견·권고·예정 ─────────────────────────

String _page1(FarmMonthlyReport r) {
  final lastDay = DateTime(r.year, r.month + 1, 0).day;
  final next = r.month == 12 ? 1 : r.month + 1;
  final (statusClass, statusIcon) = switch (r.status) {
    FarmReportStatus.good => ('st-good', '✓'),
    FarmReportStatus.watch => ('st-watch', '!'),
    FarmReportStatus.urgent => ('st-urgent', '!'),
  };

  final tiles = r.tiles.map((t) {
    final noteClass = switch (t.tone) { ReportTone.good => 'd', ReportTone.bad => 'd bad', ReportTone.plain => 'sub' };
    return '<div class="tile"><span class="l">${_e(t.label)}</span><b>${_e(t.value)}</b>'
        '<span class="$noteClass">${_e(t.note)}</span></div>';
  }).join();

  final recs = r.recommendations
      .map((rec) => rec.body.isEmpty ? '<li>${_md(rec.title)}</li>' : '<li><b>${_e(rec.title)}</b> — ${_md(rec.body)}</li>')
      .join();

  final nextItems = r.nextItems
      .map((n) => '<div><span class="sub">${_e(n.label)}</span><b>${_e(n.value)}</b><span class="sub">${_e(n.note)}</span></div>')
      .join();

  return '''
<div class="top">
  <div>
    <div class="kicker">${_e(r.orgName)} · 양식장 관리 리포트</div>
    <h1>${_e(r.farmName)}</h1>
    <div class="period">${r.isMonthly ? '${r.year}년 ${r.month}월 (${r.month}/1 ~ ${r.month}/$lastDay) 월간 리포트' : _e(r.periodLabel!)}</div>
  </div>
  <table class="meta">
    <tr><td>해역</td><td>${_e(r.seaArea)}</td></tr>
    <tr><td>품종</td><td>${_e(r.species)}</td></tr>
    <tr><td>수조</td><td>${_e(r.tanksLabel)}</td></tr>
    <tr><td>담당</td><td>수산질병관리사 ${_e(r.managerName)}</td></tr>
    <tr><td>발행일</td><td>${DateFormat('yyyy년 M월 d일').format(r.issuedAt)}</td></tr>
  </table>
</div>

<div class="status $statusClass">
  <div class="big">$statusIcon ${r.isMonthly ? '이달' : '현재'} 상태: ${r.status.label}</div>
  <p>${_md(r.statusSummary)}</p>
</div>

${tiles.isEmpty ? '' : '<div class="tiles">$tiles</div>'}

<section>
  <h2>관리원 소견 <small>담당 수산질병관리사가 작성했습니다</small></h2>
  <div class="memo">
    ${r.opinion.map((p) => '<p>${_md(p)}</p>').join('\n    ')}
    ${recs.isEmpty ? '' : '<h3 style="margin-top:12px">${r.isMonthly ? '$next월 ' : ''}관리 권고</h3><ul>$recs</ul>'}
    <div class="sign">${_e(r.orgName)} · 수산질병관리사 ${_e(r.managerName)}</div>
  </div>
</section>
${nextItems.isEmpty ? '' : '<section><h2>$next월 예정</h2><div class="next">$nextItems</div></section>'}
''';
}

// ───────────────────────── 2쪽: 해양환경·수조 DO·pH ─────────────────────────

const _ramp = ['#86b6ef', '#5598e7', '#2a78d6', '#1c5cab', '#0d366b'];
const _tankColors = ['#2a78d6', '#eb6834', '#1baf7a', '#8a4fd0'];
const _doMin = 5.0, _phMin = 7.5, _phMax = 8.5;

String _page2(FarmMonthlyReport r) {
  final m = r.month;
  final sections = <String>[];

  if (r.seaTemps.isNotEmpty) {
    final ramp = _ramp.sublist(math.max(0, _ramp.length - r.seaWeeks.length));
    final legend = [
      for (var k = 0; k < r.seaWeeks.length; k++)
        '<span class="lg" style="margin-left:6px"><i style="background:${ramp[k % ramp.length]}"></i>$m/${r.seaWeeks[k]}</span>',
    ].join();
    final alerts = r.alerts.map((a) => '<div>${_e(a.label)} <span class="${a.ok ? 'ok' : 'bad'}">${_e(a.value)}</span></div>').join();
    sections.add('''
<section>
  <h2>해양환경 데이터 <small>${_e(r.farmName)}에서 가장 가까운 관측소 · $m월 주간 값</small>
    <span style="margin-left:auto">$legend</span></h2>
  <div class="charts">
    <div><h3>수온 <span class="muted" style="font-weight:400">°C</span></h3>${_bars(r.seaTemps, r.seaWeeks, m, ramp, '수온')}</div>
    <div><h3>염도 <span class="muted" style="font-weight:400">psu</span></h3>${_bars(r.seaSalinities, r.seaWeeks, m, ramp, '염도')}</div>
  </div>
  ${alerts.isEmpty ? '' : '<div class="alerts">$alerts</div>'}
  <div class="srcline">
    <span class="sub">${_md(r.seaSummary)}</span>
    <span class="source">출처: 해양수산 공공서비스 관측값</span>
  </div>
</section>''');
  }

  if (r.tanks.isNotEmpty) {
    final legend = [
      for (var i = 0; i < r.tanks.length; i++)
        '<span class="lg"><i class="ln" style="background:${_tankColors[i % _tankColors.length]}"></i>${_e(r.tanks[i].name)}</span>',
    ].join();
    final days = r.tanks.first.days;
    final rows = [
      for (final t in r.tanks) _waterRow('${t.name} DO', t.doValues, (v) => v < _doMin),
      for (final t in r.tanks) _waterRow('${t.name} pH', t.phValues, (v) => v < _phMin || v > _phMax),
    ].join();
    sections.add('''
<section>
  <h2>수조 DO·pH <small>양식장에서 측정한 값 · 기준: DO ${_n(_doMin, 0)} mg/L 이상, pH $_phMin~$_phMax</small></h2>
  <div style="display:flex;align-items:center;gap:4px;margin-bottom:4px">
    <h3 style="margin:0">DO <span class="muted" style="font-weight:400">mg/L</span></h3>
    $legend
    <span class="lg"><i style="width:14px;height:0;border-top:2px dashed #1f8a4c;border-radius:0"></i>기준 ${_n(_doMin, 0)}</span>
  </div>
  ${_doChart(r.tanks, m)}
  <div class="tw" style="margin-top:10px">
    <table class="num"><tr><th>측정일</th>${days.map((d) => '<th>${_day(r, d)}</th>').join()}</tr>$rows</table>
  </div>
  <p class="sub" style="margin:8px 0 0">${_md(r.waterSummary)}</p>
</section>''');
  }

  return sections.join('\n').replaceFirst('<section>', '<section style="margin-top:0">');
}

String _waterRow(String name, List<double> values, bool Function(double) out) =>
    '<tr><td><b>${_e(name)}</b></td>${values.map((v) => out(v) ? '<td class="out">${_n(v)}</td>' : '<td>${_n(v)}</td>').join()}</tr>';

/// 주간 막대 그래프 (수온·염도). 막대 위에 값, 마지막 주는 굵게.
String _bars(List<double> vals, List<int> weeks, int month, List<String> ramp, String unit) {
  const w = 330.0, h = 190.0, l = 30.0, rr = 6.0, t = 16.0, b = 24.0;
  const pw = w - l - rr, ph = h - t - b;
  final top = (vals.reduce(math.max) / 10).ceil() * 10.0;
  double y(double v) => t + ph - v / top * ph;
  final n = vals.length;
  final bw = math.min(38.0, pw / n * 0.6), gap = (pw - n * bw) / n;

  final s = StringBuffer('<svg viewBox="0 0 $w $h" role="img" aria-label="$month월 주간 $unit">');
  for (var v = 0.0; v <= top; v += 10) {
    s.write('<line x1="$l" x2="${w - rr}" y1="${y(v)}" y2="${y(v)}" stroke="var(--grid)"/>'
        '<text x="${l - 5}" y="${y(v) + 3.5}" text-anchor="end" font-size="9.5" fill="var(--mut)">${v.round()}</text>');
  }
  for (var i = 0; i < n; i++) {
    final x = l + gap / 2 + i * (bw + gap), yy = y(vals[i]);
    const r = 3.0;
    s.write('<path d="M$x,${t + ph} V${yy + r} Q$x,$yy ${x + r},$yy H${x + bw - r} Q${x + bw},$yy ${x + bw},${yy + r} V${t + ph} Z" '
        'fill="${ramp[i % ramp.length]}"/>');
    s.write('<text x="${x + bw / 2}" y="${yy - 4}" text-anchor="middle" font-size="10" fill="var(--ink)" '
        'font-weight="${i == n - 1 ? 700 : 400}">${_n(vals[i])}</text>');
    if (i < weeks.length) {
      s.write('<text x="${x + bw / 2}" y="${h - 7}" text-anchor="middle" font-size="10" fill="var(--sec)">$month/${weeks[i]}</text>');
    }
  }
  s.write('<line x1="$l" x2="${w - rr}" y1="${t + ph}" y2="${t + ph}" stroke="#b9c3c6"/></svg>');
  return s.toString();
}

/// 수조별 DO 꺾은선. 기준(5 mg/L) 위는 옅은 초록, 기준선은 점선.
String _doChart(List<ReportTankSeries> tanks, int month) {
  const w = 690.0, h = 200.0, l = 30.0, rr = 14.0, t = 14.0, b = 24.0;
  const pw = w - l - rr, ph = h - t - b;
  final all = [for (final tank in tanks) ...tank.doValues];
  final min = math.min(4.0, all.reduce(math.min).floorToDouble());
  final max = math.max(8.0, all.reduce(math.max).ceilToDouble());
  final days = tanks.first.days;
  double x(int i) => days.length == 1 ? l + pw / 2 : l + 18 + i * (pw - 36) / (days.length - 1);
  double y(double v) => t + ph - (v - min) / (max - min) * ph;

  final s = StringBuffer('<svg viewBox="0 0 $w $h" role="img" aria-label="수조별 $month월 DO">');
  for (var v = min; v <= max; v += 1) {
    s.write('<line x1="$l" x2="${w - rr}" y1="${y(v)}" y2="${y(v)}" stroke="var(--grid)"/>'
        '<text x="${l - 5}" y="${y(v) + 3.5}" text-anchor="end" font-size="9.5" fill="var(--mut)">${v.round()}</text>');
  }
  s.write('<rect x="$l" y="$t" width="$pw" height="${y(_doMin) - t}" fill="#1f8a4c" opacity=".06"/>'
      '<line x1="$l" x2="${w - rr}" y1="${y(_doMin)}" y2="${y(_doMin)}" stroke="#1f8a4c" stroke-dasharray="4 3"/>'
      '<text x="${l + 4}" y="${y(_doMin) + 12}" font-size="9.5" fill="#1f8a4c">기준 ${_n(_doMin, 0)} mg/L</text>');
  for (var k = 0; k < tanks.length; k++) {
    final c = _tankColors[k % _tankColors.length];
    final vals = tanks[k].doValues;
    // 첫 수조는 점 위, 나머지는 점 아래에 값을 적어 겹치지 않게 한다.
    final dy = k == 0 ? -9 : 15;
    s.write('<polyline fill="none" stroke="$c" stroke-width="2" points="${[for (var i = 0; i < vals.length; i++) '${x(i)},${y(vals[i])}'].join(' ')}"/>');
    for (var i = 0; i < vals.length; i++) {
      s.write('<circle cx="${x(i)}" cy="${y(vals[i])}" r="4" fill="$c" stroke="#fff" stroke-width="2"/>'
          '<text x="${x(i)}" y="${y(vals[i]) + dy}" text-anchor="middle" font-size="9.5" '
          'fill="${vals[i] < _doMin ? 'var(--crit)' : 'var(--ink)'}">${_n(vals[i])}</text>');
    }
  }
  for (var i = 0; i < days.length; i++) {
    s.write('<text x="${x(i)}" y="${h - 7}" text-anchor="middle" font-size="10" fill="var(--sec)">$month/${days[i]}</text>');
  }
  s.write('<line x1="$l" x2="${w - rr}" y1="${t + ph}" y2="${t + ph}" stroke="#b9c3c6"/></svg>');
  return s.toString();
}

// ───────────────────────── 3쪽: 기록·검사·배달·문의 ─────────────────────────

String _page3(FarmMonthlyReport r) {
  final m = r.month;
  final sections = <String>[];

  final waterRow = _waterLogRow(r);
  if (r.logs.isNotEmpty || waterRow != null) {
    final rows = [
      for (final e in r.logs)
        '<tr><td style="white-space:nowrap">${_day(r, e.day)}</td><td>${_chip(e.type, e.label ?? e.type.label)}</td>'
            '<td>${_e(e.tank)}</td><td>${_md(e.content)}</td></tr>',
      ?waterRow,
    ].join();
    sections.add('<section><h2>이달 기록 요약 <small>$m월 동안 관리원과 양식장이 남긴 기록</small></h2>'
        '<div class="tw"><table><tr><th>날짜</th><th>구분</th><th>수조</th><th>내용</th></tr>$rows</table></div></section>');
  }

  if (r.exams.isNotEmpty) {
    final rows = r.exams
        .map((e) => '<tr><td>$m/${e.day}</td><td>${_chip(e.type, e.label)}</td><td>${_e(e.tank)}</td><td>${_e(e.target)}</td>'
            '<td><span class="pill ${e.ok ? 'p-ok' : 'p-bad'}">${_e(e.result)}</span></td></tr>')
        .join();
    sections.add('<section><h2>검사 결과</h2><div class="tw"><table>'
        '<tr><th>날짜</th><th>검사</th><th>수조</th><th>대상·항목</th><th>결과</th></tr>$rows</table></div></section>');
  }

  if (r.deliveries.isNotEmpty) {
    final rows = r.deliveries
        .map((d) => '<tr><td>$m/${d.day}</td><td>${_e(d.item)}</td><td>${_e(d.qty)}</td><td>${_e(d.purpose)}</td>'
            '<td><span class="pill ${d.done ? 'p-ok' : 'p-plan'}">${d.done ? '배달 완료' : '배달 예정'}</span></td></tr>')
        .join();
    sections.add('<section><h2>약품·자재 배달</h2><div class="tw"><table>'
        '<tr><th>날짜</th><th>품목</th><th>수량</th><th>용도</th><th>상태</th></tr>$rows</table></div></section>');
  }

  sections.add('''
<section>
  <h2>문의</h2>
  <div class="contact">
    <div><span class="sub">담당 수산질병관리사</span><br><b>${_e(r.managerName)}</b> · ${_e(r.managerPhone)}</div>
    <div><span class="sub">${_e(r.orgName)}</span><br>${_e(r.orgContact)}</div>
  </div>
</section>
<section>
  <div class="notice">
    <p>· 이 리포트는 해양수산 공공서비스의 해양환경 관측값과, 수산질병관리원·양식장이 ${r.isMonthly ? '$m월' : '이 기간'} 동안 남긴 현장 기록을 합쳐 만들었습니다.</p>
    <p>· 질병 판단과 처방은 담당 수산질병관리사가 합니다. 궁금한 점은 위 연락처로 문의해 주세요.</p>
    <p>· 이 리포트는 ${_e(r.farmName)}에만 보내 드리는 자료입니다.</p>
  </div>
</section>''');

  return sections.join('\n').replaceFirst('<section>', '<section style="margin-top:0">');
}

/// 기록 표 마지막 줄: 한 달 DO·pH 측정을 한 줄로 묶는다.
String? _waterLogRow(FarmMonthlyReport r) {
  if (r.tanks.isEmpty) return null;
  final days = r.tanks.first.days;
  if (days.isEmpty) return null;
  final count = r.tanks.fold<int>(0, (s, t) => s + t.days.length);
  final out = r.tanks.fold<int>(
    0,
    (s, t) => s + t.doValues.where((v) => v < _doMin).length + t.phValues.where((v) => v < _phMin || v > _phMax).length,
  );
  final m = r.month;
  final range = days.length == 1 ? '$m/${days.first}' : '$m/${days.first} ~ $m/${days.last}';
  final result = out == 0 ? '모두 기준 안' : '기준 밖 $out회';
  return '<tr><td style="white-space:nowrap">$range</td><td>${_chip(MonthlyEventType.water, MonthlyEventType.water.label)}</td>'
      '<td>${_e(r.tanks.map((t) => t.name).join(', '))}</td><td>$count회 측정 — $result (2쪽 참고)</td></tr>';
}

// ───────────────────────── helpers ─────────────────────────

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

String _day(FarmMonthlyReport r, int day) => '${r.month}/$day (${_weekdays[DateTime(r.year, r.month, day).weekday - 1]})';

String _chip(MonthlyEventType type, String label) => '<span class="chip" style="--c:var(--t-${type.name})">${_e(label)}</span>';

String _n(double v, [int digits = 1]) => v.toStringAsFixed(digits);

String _e(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

/// 이스케이프 후 `**굵게**` → `<b>굵게</b>`.
String _md(String s) => _e(s).replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => '<b>${m[1]}</b>');

const _css = '''
:root{
  --ink:#0e2f3b; --sec:#52606a; --mut:#8a959b; --line:#d0dee2; --grid:#e6ecee;
  --soft:#f3f8f8; --head:#dcefee; --ok-bg:#d8f1e3; --ok:#135c32;
  --crit:#d03b3b; --bad-bg:#fbe3e1; --warn-bg:#fdf0d5; --warn:#8a5a00;
  --t-patrol:#2a78d6; --t-delivery:#eb6834; --t-diag:#1baf7a; --t-exam:#eda100; --t-safety:#e87ba4; --t-vacc:#008300; --t-water:#4a3aa7;
  --serif:"Noto Serif KR","Noto Serif CJK KR",serif;
  --sans:"Noto Sans KR","Noto Sans CJK KR",system-ui,-apple-system,"Apple SD Gothic Neo","Malgun Gothic",sans-serif;
}
*{box-sizing:border-box}
html,body{margin:0}
body{background:#e9eef0;color:var(--ink);font-family:var(--sans);font-size:12.5px;line-height:1.55;-webkit-print-color-adjust:exact;print-color-adjust:exact}
.pages{padding:12px 0 24px;display:flex;flex-direction:column;align-items:center;gap:18px}
.page{width:794px;height:1123px;background:#fff;box-shadow:0 2px 12px rgba(14,47,59,.15);padding:48px 52px 40px;position:relative;display:flex;flex-direction:column;overflow:hidden}
.pfoot{margin-top:auto;display:flex;justify-content:space-between;font-size:10px;color:var(--mut);border-top:1px solid var(--grid);padding-top:8px}
h1{font-family:var(--serif);font-size:30px;margin:0;letter-spacing:-.5px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
h2{font-family:var(--serif);font-size:16px;margin:0 0 10px;display:flex;align-items:baseline;gap:8px}
h2 small{font-family:var(--sans);font-weight:400;font-size:11.5px;color:var(--sec)}
h3{font-size:12.5px;margin:0 0 6px}
.sub{color:var(--sec);font-size:11.5px}
.muted{color:var(--mut)}
.top{display:flex;justify-content:space-between;align-items:flex-start;gap:20px;border-bottom:2px solid var(--ink);padding-bottom:16px}
.top>div{flex:1;min-width:0}
.kicker{font-size:12px;color:var(--sec);font-weight:700;letter-spacing:.5px;margin-bottom:6px}
.period{font-size:14px;margin-top:6px;color:var(--sec)}
.meta{font-size:11.5px;border-collapse:collapse;width:auto!important;flex:none}
.meta td{border-top:none;padding:2px 0 2px 12px;vertical-align:top;white-space:nowrap}
.meta td:first-child{color:var(--mut);padding-left:0}
.status{margin-top:18px;border-radius:10px;padding:14px 18px;display:flex;gap:14px;align-items:center}
.status .big{font-family:var(--serif);font-size:20px;white-space:nowrap;display:flex;align-items:center;gap:6px}
.status p{margin:0;font-size:13px}
.st-good{background:var(--ok-bg)}.st-good .big{color:var(--ok)}
.st-watch{background:var(--warn-bg)}.st-watch .big{color:var(--warn)}
.st-urgent{background:var(--bad-bg)}.st-urgent .big{color:var(--crit)}
.tiles{display:grid;grid-template-columns:repeat(4,1fr);gap:10px;margin-top:14px}
.tile{border:1px solid var(--line);border-radius:8px;padding:10px 12px}
.tile .l{font-size:11px;color:var(--sec)}
.tile b{font-family:var(--serif);font-size:22px;display:block;line-height:1.3}
.tile .d{font-size:11px;color:var(--ok);font-weight:700}
.tile .d.bad{color:var(--crit)}
section{margin-top:22px}
.memo{border:1px solid var(--line);border-left:4px solid var(--ink);border-radius:8px;padding:16px 18px}
.memo p{margin:0 0 10px;font-size:13px}
.memo ul{margin:6px 0 0;padding-left:18px}
.memo li{margin-bottom:6px;font-size:12.5px}
.sign{display:flex;justify-content:flex-end;gap:8px;margin-top:10px;font-size:11.5px;color:var(--sec)}
.next{display:grid;grid-template-columns:repeat(3,1fr);gap:10px}
.next div{border:1px solid var(--line);border-radius:8px;padding:10px 12px}
.next b{display:block;font-size:14px}
.charts{display:grid;grid-template-columns:1fr 1fr;gap:18px}
svg{width:100%;height:auto;display:block}
.srcline{display:flex;justify-content:space-between;align-items:flex-end;gap:10px;margin-top:4px}
.source{font-size:9.5px;color:var(--mut);text-align:right;margin-left:auto;flex:none}
.alerts{display:grid;grid-template-columns:repeat(4,1fr);gap:8px;margin-top:12px}
.alerts div{border:1px solid var(--line);border-radius:8px;padding:7px 10px;font-size:11.5px;display:flex;justify-content:space-between;gap:6px}
.alerts span.ok{color:var(--ok);font-weight:700}
.alerts span.bad{color:var(--crit);font-weight:700}
table{border-collapse:collapse;width:100%}
th{background:var(--head);text-align:left;font-size:11px;padding:6px 8px;white-space:nowrap;font-weight:700}
td{padding:6px 8px;border-top:1px solid var(--grid);font-size:11.5px;vertical-align:top}
td.out{color:var(--crit);font-weight:700}
.tw{border:1px solid var(--line);border-radius:8px;overflow:hidden}
.num td{text-align:center}.num td:first-child,.num th:first-child{text-align:left}
.num th{text-align:center}
.chip{display:inline-block;font-size:10.5px;padding:1px 6px;border-radius:4px;border-left:3px solid var(--c);background:color-mix(in srgb,var(--c) 13%,#fff);white-space:nowrap}
.pill{display:inline-block;border-radius:999px;padding:0 8px;font-size:10.5px;font-weight:700;white-space:nowrap}
.p-ok{background:var(--ok-bg);color:var(--ok)}.p-plan{background:#e4ddf6;color:#3b2e86}.p-bad{background:var(--bad-bg);color:var(--crit)}
.lg{font-family:var(--sans);font-weight:400;display:inline-flex;align-items:center;gap:5px;font-size:11px;color:var(--sec);margin-left:10px}
.lg i{width:10px;height:10px;border-radius:2px;display:inline-block}
.lg i.ln{height:3px;border-radius:2px}
.notice{background:var(--soft);border-radius:8px;padding:12px 14px;font-size:11px;color:var(--sec)}
.notice p{margin:0 0 4px}
.contact{display:grid;grid-template-columns:1fr 1fr;gap:10px}
.contact div{border:1px solid var(--line);border-radius:8px;padding:10px 12px;font-size:12px}
@media print{
  @page{size:A4 portrait;margin:0}
  body{background:#fff}
  .pages{padding:0;gap:0;display:block;zoom:1!important}
  .page{box-shadow:none;width:210mm;height:297mm;break-after:page;page-break-after:always}
  .page:last-child{break-after:auto;page-break-after:auto}
}
''';
