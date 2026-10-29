import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../../core/theme/app_colors.dart';
import '../../data/models/ai_report.dart';

/// The AI 리포트 as the farm (or the 원장님) receives it — symterAI's
/// ReportDocument form: 기본 정보 → the sections, each with its tiles/charts
/// underneath → 전문가 최종 의견. Everything in the charts comes from
/// [AiReport.meta] (code-computed from the memos), never from the AI text.
///
/// A farm report ([AiReport.isAgency] false) is the 양식장 관리 리포트; an
/// agency report is the 관리원 종합 리포트 over every farm.
class AiReportDocument extends StatelessWidget {
  const AiReportDocument({
    super.key,
    required this.report,
    required this.farmName,
    required this.orgName,
    this.onEditOpinion,
    this.onItemTap,
  });

  final AiReport report;
  final String farmName;
  final String orgName;

  /// Shown as 의견 작성 next to 전문가 최종 의견 (drafts only).
  final VoidCallback? onEditOpinion;

  /// 근거 확인: an item line was tapped (staff only — null on the farm view).
  final void Function(String sectionTitle, String line)? onItemTap;

  /// Same titles and order as FARM_SECTIONS in server/src/lib/ai/prompts.js.
  static const sectionTitles = [
    '종합 관리 요약',
    '현장 점검 및 메모 분석',
    '질병 및 건강 관리 현황',
    '해양환경 및 공공데이터',
    '이전 기간 대비 변화',
    '미해결 문제 및 후속 관리',
    '다음 관리 계획',
  ];

  /// Same titles and order as AGENCY_SECTIONS in server/src/lib/ai/prompts.js.
  static const agencySectionTitles = [
    '이번 기간 전체 현황',
    '주제별 종합',
    '주의가 필요한 양식장',
    '폐사 현황',
    '해역 수온 참고 자료',
    '다음 확인 사항',
  ];

  static List<String> titlesFor(AiReport r) => r.isAgency ? agencySectionTitles : sectionTitles;

  @override
  Widget build(BuildContext context) {
    final r = report;
    final m = r.meta;
    final sections = parseAiReportBody(r.body ?? '');
    // Reports made before the form (no meta) or whose headings were edited
    // away just show their text.
    final structured = m != null && titlesFor(r).every((t) => sections.any((s) => s.title == t));
    final fmt = DateFormat('yyyy년 M월 d일');
    final recordPeriod = m?['recordPeriod'] as Map<String, dynamic>?;
    final authors = ((m?['authors'] as List<dynamic>?) ?? []).cast<String>();

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (r.isDraft)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: AppColors.warningTint, borderRadius: BorderRadius.circular(8)),
              child: const Text('초안 — 전문가 확인 전입니다. 확정 후 최종본으로 공유하세요.',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.warningTintInk)),
            ),
          Text(r.isAgency ? '관리원 종합 리포트' : '양식장 관리 리포트',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          if (r.isAgency)
            _MetaTable(rows: [
              ('수산질병관리원', orgName),
              ('대상 기간', '${r.periodStart} ~ ${r.periodEnd}'),
              if (m != null) ('관리 양식장', '${m['farmCount']}곳 (이 기간 메모가 있는 양식장 ${m['activeFarmCount']}곳)'),
              ('입력 범위', '메모 ${r.memoCount}건'),
              ('리포트 생성일', fmt.format(r.createdAt.toLocal())),
              if (r.confirmedAt != null) ('확정일', fmt.format(r.confirmedAt!.toLocal())),
            ])
          else
            _MetaTable(rows: [
              ('양식장', farmName),
              ('대상 기간', '${r.periodStart} ~ ${r.periodEnd}'),
              ('수산질병관리원', orgName),
              ('담당', r.confirmedByName ?? (authors.isNotEmpty ? authors.join(', ') : '(확정 시 표시)')),
              if (recordPeriod != null) ('메모 기록 기간', '${recordPeriod['first']} ~ ${recordPeriod['last']}'),
              ('입력 범위', '메모 ${r.memoCount}건${r.commentCount > 0 ? ' · 연결 댓글 ${r.commentCount}개 포함' : ''}'),
              ('리포트 생성일', fmt.format(r.createdAt.toLocal())),
              if (r.confirmedAt != null) ('확정일', fmt.format(r.confirmedAt!.toLocal())),
              if (r.sentAt != null && r.isSent) ('발송일', fmt.format(r.sentAt!.toLocal())),
            ]),
          for (final s in sections) ...[
            const SizedBox(height: 22),
            _SectionHeading(s.title),
            for (final line in s.lines)
              _ItemLine(line: line, onTap: onItemTap == null ? null : () => onItemTap!(s.title, line)),
            if (structured) ...(r.isAgency ? _agencyExtras(s.title, m) : _extras(s.title, r, m)),
          ],
          if (structured && r.isAgency) ..._agencyTable(m),
          const SizedBox(height: 22),
          _OpinionSection(report: r, onEdit: onEditOpinion),
          const SizedBox(height: 18),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),
          const Text('외부 관측: 국립수산과학원 실시간 해양관측·적조 속보(리포트 작성 시점에 조회) · 양식장 수조 실측값이 아닙니다',
              style: TextStyle(fontSize: 10.5, color: AppColors.textMuted, height: 1.45)),
        ],
      ),
    );
  }

  List<Widget> _agencyExtras(String title, Map<String, dynamic> m) {
    final rows = ((m['rows'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();
    final deaths = (m['deathTotals'] as Map<String, dynamic>?) ?? const {};
    final open = ((m['open'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();
    final topics = ((m['topicTotals'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();
    final stations = ((m['stations'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();
    final total = rows.fold<int>(0, (n, x) => n + (x['memos'] as int? ?? 0));
    final max = deaths['max'] as int? ?? 0;
    String num(Object? v) => v is double && v == v.roundToDouble() ? v.toInt().toString() : '$v';

    switch (agencySectionTitles.indexOf(title)) {
      case 0:
        return [
          _Tiles([
            ('관리 양식장', '${m['farmCount']}곳', null),
            ('관리원 기록', '$total건', null),
            ('확인된 폐사', max > 0 ? _range(deaths['min'] as int? ?? 0, max) : (deaths['events'] as int? ?? 0) > 0 ? '마리수 미확정' : '없음', kindColor('폐사')),
            ('후속 확인 필요', '${open.length}건', null),
          ]),
        ];
      case 1:
        return [
          if (topics.isNotEmpty) _CountRows([for (final t in topics) (t['topic'] as String, '${t['count']}건')]),
          if (rows.any((x) => (x['memos'] as int? ?? 0) > 0)) ...[
            const _Sub('양식장 × 주제'),
            _TopicMatrix(rows: rows, topics: ((m['topicOrder'] as List<dynamic>?) ?? []).cast<String>()),
          ],
        ];
      case 3:
        final withDeaths = rows.where((x) => (x['deaths'] as int? ?? 0) > 0).toList();
        if (withDeaths.isEmpty) return const [_Muted('폐사가 적힌 기록이 없습니다.')];
        return [
          _CountRows([
            for (final x in withDeaths)
              (
                x['name'] as String,
                [
                  if ((x['deathsMax'] as int? ?? 0) > 0) _range(x['deathsMin'] as int? ?? 0, x['deathsMax'] as int),
                  if ((x['deathsUnknown'] as int? ?? 0) > 0) '수량 미기재 ${x['deathsUnknown']}건',
                ].join(' · '),
              ),
          ]),
        ];
      case 4:
        if (stations.isEmpty) return const [_Muted('연결된 관측소가 없습니다.')];
        return [
          _CountRows([
            for (final st in stations)
              (
                '${st['name']} (양식장 ${st['farms']}곳)',
                st['observation'] == null ? '자료 없음' : '${(st['observation'] as Map)['layer']} ${num((st['observation'] as Map)['waterTempC'])}℃',
              ),
          ]),
          const _Muted('관측소 값은 리포트 작성 시점의 실시간 값이며 기간 평균이 아닙니다.'),
        ];
      case 5:
        return [_OpenItems(items: open)];
      default:
        return const [];
    }
  }

  List<Widget> _agencyTable(Map<String, dynamic> m) {
    final rows = ((m['rows'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();
    if (rows.isEmpty) return const [];
    String num(Object? v) => v == null ? '-' : (v is double && v == v.roundToDouble() ? v.toInt().toString() : '$v');
    return [
      const SizedBox(height: 22),
      const _SectionHeading('양식장별 현황 표'),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 34,
          dataRowMinHeight: 32,
          dataRowMaxHeight: 40,
          horizontalMargin: 4,
          columnSpacing: 14,
          headingTextStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
          dataTextStyle: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
          columns: const [
            DataColumn(label: Text('양식장')),
            DataColumn(label: Text('지역')),
            DataColumn(label: Text('메모'), numeric: true),
            DataColumn(label: Text('방문'), numeric: true),
            DataColumn(label: Text('폐사'), numeric: true),
            DataColumn(label: Text('접종'), numeric: true),
            DataColumn(label: Text('관측소')),
            DataColumn(label: Text('수온'), numeric: true),
          ],
          rows: [
            for (final x in rows)
              DataRow(cells: [
                DataCell(Text('${x['name']}')),
                DataCell(Text((x['region'] as String?)?.isNotEmpty == true ? x['region'] as String : '-')),
                DataCell(Text('${x['memos']}')),
                DataCell(Text('${x['visits']}')),
                DataCell(Text((x['deathsMax'] as int? ?? 0) > 0
                    ? _range(x['deathsMin'] as int? ?? 0, x['deathsMax'] as int)
                    : (x['deaths'] as int? ?? 0) > 0
                        ? '미확정'
                        : '0')),
                DataCell(Text('${x['vaccinations']}')),
                DataCell(Text('${x['station'] ?? '-'}')),
                DataCell(Text(x['waterTempC'] == null ? '-' : '${num(x['waterTempC'])}℃')),
              ]),
          ],
        ),
      ),
    ];
  }

  List<Widget> _extras(String title, AiReport r, Map<String, dynamic> m) {
    final an = (m['analysis'] as Map<String, dynamic>?) ?? const {};
    final deaths = (an['deaths'] as Map<String, dynamic>?) ?? const {};
    final open = ((an['open'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();
    final tanks = ((m['tanks'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();
    final events = ((m['events'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();
    final byKind = ((m['memoStats'] as Map<String, dynamic>?)?['byKind'] as Map<String, dynamic>?) ?? const {};
    final topics = ((an['topics'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();
    final deathEvents = deaths['events'] as int? ?? 0;
    final total = an['total'] as int? ?? r.memoCount;

    switch (sectionTitles.indexOf(title)) {
      case 0:
        final max = deaths['max'] as int? ?? 0;
        return [
          _Tiles([
            ('현장 기록', '$total건', null),
            ('확인된 폐사', max > 0 ? _range(deaths['min'] as int? ?? 0, max) : deathEvents > 0 ? '마리수 미확정' : '없음', kindColor('폐사')),
            ('후속 확인 필요', '${open.length}건', null),
            ('언급된 수조', '${tanks.length}개', null),
          ]),
        ];
      case 1:
        final kinds = [
          ...reportKindOrder,
          for (final k in byKind.keys)
            if (!reportKindOrder.contains(k)) k,
        ];
        return [
          _Tiles([for (final k in kinds) (k, '${byKind[k] ?? 0}건', kindColor(k))]),
          if (events.isNotEmpty) _RecordTimeline(events: events, from: r.periodStart, to: r.periodEnd),
          if (tanks.isNotEmpty) ...[
            const _Sub('수조별 관찰 건수'),
            _CountRows([for (final t in tanks) ('${t['tank']}번 수조', '${t['count']}건')]),
          ],
        ];
      case 2:
        return [
          if (topics.isNotEmpty) _CountRows([for (final t in topics) (t['topic'] as String, '${t['count']}건')]),
          if (deathEvents > 0)
            _DeathChart(
              byDay: ((deaths['byDay'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>(),
              from: r.periodStart,
              to: r.periodEnd,
            ),
        ];
      case 3:
        return _environment(m);
      case 4:
        final prev = m['prev'] as Map<String, dynamic>?;
        if (prev == null) return const [];
        return [
          _Tiles([
            ('현장 기록 (이전 → 이번 기간)', '${prev['total']} → $total건', null),
            ('폐사 기록 (이전 → 이번 기간)', '${prev['deathEvents']} → $deathEvents건', kindColor('폐사')),
          ]),
        ];
      case 5:
        return [_OpenItems(items: open)];
      default:
        return const [];
    }
  }

  List<Widget> _environment(Map<String, dynamic> m) {
    final measurements = ((m['measurements'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();
    final pub = m['publicData'] as Map<String, dynamic>?;
    final station = pub?['station'] as Map<String, dynamic>?;
    final obs = pub?['observation'] as Map<String, dynamic>?;
    final redTide = pub?['redTide'] as Map<String, dynamic>?;
    String num(Object? v) => v is double && v == v.roundToDouble() ? v.toInt().toString() : '$v';

    return [
      if (measurements.isNotEmpty) ...[
        const _Sub('현장 실측(메모에 적힌 값)'),
        for (final x in measurements)
          _Bullet('${_md(x['date'] as String)} '
              '${((x['tanks'] as List<dynamic>?) ?? []).isEmpty ? '' : '${(x['tanks'] as List<dynamic>).join('·')}번 수조 '}'
              '${x['name']} ${num(x['value'])}${x['unit']}'),
      ],
      const _Sub('외부 관측(공공데이터)'),
      if (obs != null)
        _Tiles([
          ('${station?['name'] ?? '관측소'} ${obs['layer']} 수온', '${num(obs['waterTempC'])}℃', null),
        ])
      else
        const _Muted('외부 관측 수온 자료를 가져오지 못했습니다.'),
      if (obs != null) _Muted('관측 ${obs['observedDate']} ${obs['observedTime']} · 리포트 작성 시점의 실시간 값이며 기간 평균이 아닙니다.'),
      if (pub != null) _PublicSource(pub: pub, redTide: redTide),
    ];
  }
}

// ───────── body parsing ─────────

class AiReportSection {
  AiReportSection(this.title);
  final String title;
  final List<String> lines = [];
}

/// "## 제목" starts a section; every other non-empty line belongs to it.
List<AiReportSection> parseAiReportBody(String body) {
  final out = <AiReportSection>[];
  for (final raw in body.split(RegExp(r'\r?\n'))) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('## ')) {
      out.add(AiReportSection(line.substring(3).trim()));
    } else {
      if (out.isEmpty) out.add(AiReportSection(''));
      out.last.lines.add(line);
    }
  }
  return out;
}

// ───────── colors & labels ─────────

/// Memo kinds in chart order (symterAI REPORT_KIND_ORDER).
const reportKindOrder = ['폐사', '접종', '방문', '배달', '할일'];

/// One fixed color per memo kind, same in every chart (symterAI KIND_COLOR).
Color kindColor(String kind) => switch (kind) {
      '방문' => const Color(0xFF2A78D6),
      '폐사' => const Color(0xFFEB6834),
      '접종' => const Color(0xFF1BAF7A),
      '배달' => const Color(0xFFEDA100),
      '할일' => const Color(0xFFE87BA4),
      '문의' => const Color(0xFF008300),
      _ => const Color(0xFF8A96A3),
    };

const _topicColor = Color(0xFF4A6785);
const _deathLight = Color(0xFFF6C9B6);
const _grid = Color(0xFFE3E9EF);
const _axis = Color(0xFF5D6B7A);

final _fmtNum = NumberFormat.decimalPattern('ko_KR');
String _range(int min, int max) => min == max ? '${_fmtNum.format(min)}마리' : '${_fmtNum.format(min)}~${_fmtNum.format(max)}마리';
String _md(String date) => '${int.parse(date.substring(5, 7))}월 ${int.parse(date.substring(8, 10))}일';
DateTime _day(String date) => DateTime.utc(int.parse(date.substring(0, 4)), int.parse(date.substring(5, 7)), int.parse(date.substring(8, 10)));

// ───────── building blocks ─────────

class _MetaTable extends StatelessWidget {
  const _MetaTable({required this.rows});
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (k, v) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 104, child: Text(k, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted))),
                Expanded(child: Text(v, style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary))),
              ],
            ),
          ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.only(bottom: 6),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.brand, width: 2))),
      child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.brand)),
    );
  }
}

class _Sub extends StatelessWidget {
  const _Sub(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
      );
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(text, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.45)),
      );
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4, left: 4),
        child: Text('•  $text', style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary, height: 1.45)),
      );
}

final _tagRe = RegExp(r'〔([^〕]*)〕');

/// One "- 항목" line as the form prints it: the sentence with its 〔현장 실측〕
/// / 〔근거: …〕 tags inline (근거 muted), plus any 〔확인 필요: …〕 from the
/// evidence check as a note underneath (staff only — gone once fixed).
class _ItemLine extends StatelessWidget {
  const _ItemLine({required this.line, this.onTap});
  final String line;

  /// 근거 확인 (staff view only).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bullet = line.startsWith('- ');
    final text = bullet ? line.substring(2) : line;
    final flags = <String>[];
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _tagRe.allMatches(text)) {
      final tag = m.group(1)!;
      spans.add(TextSpan(text: text.substring(last, m.start)));
      last = m.end;
      if (tag.startsWith('확인 필요:')) {
        flags.add(tag.substring('확인 필요:'.length).trim());
      } else if (tag.startsWith('근거')) {
        spans.add(TextSpan(text: '〔$tag〕', style: const TextStyle(color: AppColors.textMuted)));
      } else if (tag.contains('확인 필요')) {
        spans.add(TextSpan(text: '〔$tag〕', style: const TextStyle(color: AppColors.dangerDark, fontWeight: FontWeight.w700)));
      } else {
        spans.add(TextSpan(text: '〔$tag〕'));
      }
    }
    spans.add(TextSpan(text: text.substring(last)));

    final item = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bullet)
            const Padding(
              padding: EdgeInsets.only(top: 8, right: 8, left: 4),
              child: CircleAvatar(radius: 2.5, backgroundColor: AppColors.textPrimary),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(TextSpan(children: spans), style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.6)),
                for (final f in flags)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.warningTint, borderRadius: BorderRadius.circular(6)),
                    child: Text('확인 필요: $f', style: const TextStyle(fontSize: 10.5, color: AppColors.warningTintInk, height: 1.4)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return item;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(6), child: item);
  }
}

/// Big number over a label, wrapping into rows (symterAI Tiles).
class _Tiles extends StatelessWidget {
  const _Tiles(this.items);
  final List<(String, String, Color?)> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: LayoutBuilder(builder: (context, c) {
        // As many per row as fit at ~68px each (the form shows 4–5 across).
        final perRow = (c.maxWidth / 68).floor().clamp(2, math.min(5, items.length));
        final w = (c.maxWidth - (perRow - 1) * 12) / perRow;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final (label, value, color) in items)
              SizedBox(
                width: w,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (color != null) ...[
                          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                        ],
                        Flexible(child: Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.3))),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        );
      }),
    );
  }
}

/// "이름 ........ N건" rows (수조별 관찰 건수, 주제별 기록 건수).
class _CountRows extends StatelessWidget {
  const _CountRows(this.rows);
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        children: [
          for (final (name, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
              child: Row(
                children: [
                  Container(width: 3, height: 14, color: _topicColor),
                  const SizedBox(width: 8),
                  Expanded(child: Text(name, style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary))),
                  Text(value, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.items);
  final List<(String, Color, bool)> items; // label, color, dot (else bar)

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        for (final (label, color, dot) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: dot ? 8 : 12,
                height: 8,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(dot ? 4 : 2)),
              ),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
      ],
    );
  }
}

/// Memo days per kind across the report period (symterAI RecordTimeline).
class _RecordTimeline extends StatelessWidget {
  const _RecordTimeline({required this.events, required this.from, required this.to});
  final List<Map<String, dynamic>> events;
  final String from;
  final String to;

  @override
  Widget build(BuildContext context) {
    final kinds = {for (final e in events) e['kind'] as String};
    final lanes = [
      ...reportKindOrder.where(kinds.contains),
      ...kinds.where((k) => !reportKindOrder.contains(k)),
    ];
    const lane = 26.0;
    final height = 8 + lanes.length * lane + 24;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: height,
            width: double.infinity,
            child: CustomPaint(painter: _TimelinePainter(events: events, lanes: lanes, from: _day(from), to: _day(to))),
          ),
          const SizedBox(height: 6),
          _Legend([for (final k in lanes) (k, kindColor(k), true)]),
        ],
      ),
    );
  }
}

/// Shared x axis for the period charts: one slot per day, from..to.
class _DayAxis {
  _DayAxis(this.from, this.to, this.left, this.right, this.width);
  final DateTime from;
  final DateTime to;
  final double left;
  final double right;
  final double width;

  int get days => to.difference(from).inDays + 1;
  double x(DateTime d) {
    final span = math.max(1, days - 1);
    return left + (d.difference(from).inDays / span) * (width - left - right);
  }

  /// First, middle and last day labels.
  List<(DateTime, TextAlign)> get ticks {
    final mid = from.add(Duration(days: (days - 1) ~/ 2));
    return [(from, TextAlign.left), if (days > 2) (mid, TextAlign.center), (to, TextAlign.right)];
  }

  static String label(DateTime d) => '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

void _text(Canvas canvas, String s, Offset at, {double size = 10.5, Color color = _axis, TextAlign align = TextAlign.left, FontWeight? weight}) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: TextStyle(fontSize: size, color: color, fontWeight: weight)),
    textDirection: TextDirection.ltr,
  )..layout();
  final dx = switch (align) {
    TextAlign.right => at.dx - tp.width,
    TextAlign.center => at.dx - tp.width / 2,
    _ => at.dx,
  };
  tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({required this.events, required this.lanes, required this.from, required this.to});
  final List<Map<String, dynamic>> events;
  final List<String> lanes;
  final DateTime from;
  final DateTime to;

  @override
  void paint(Canvas canvas, Size size) {
    final ax = _DayAxis(from, to, 40, 10, size.width);
    const lane = 26.0;
    double laneY(int n) => 8 + 12 + n * lane;
    final gridPaint = Paint()..color = _grid;
    for (var n = 0; n < lanes.length; n++) {
      final k = lanes[n];
      final y = laneY(n);
      canvas.drawLine(Offset(ax.left, y), Offset(size.width - ax.right, y), gridPaint);
      _text(canvas, k, Offset(ax.left - 6, y), align: TextAlign.right);
      final byDay = <DateTime, int>{};
      for (final e in events.where((e) => e['kind'] == k)) {
        final d = _day(e['date'] as String);
        byDay[d] = (byDay[d] ?? 0) + 1;
      }
      for (final MapEntry(key: d, value: c) in byDay.entries) {
        final center = Offset(ax.x(d), y);
        final r = c > 1 ? 8.0 : 6.0;
        canvas.drawCircle(center, r + 2, Paint()..color = Colors.white);
        canvas.drawCircle(center, r, Paint()..color = kindColor(k));
        if (c > 1) _text(canvas, '$c', center, size: 9.5, color: Colors.white, align: TextAlign.center, weight: FontWeight.w700);
      }
    }
    for (final (d, align) in ax.ticks) {
      _text(canvas, _DayAxis.label(d), Offset(ax.x(d), size.height - 8), align: align);
    }
  }

  @override
  bool shouldRepaint(_TimelinePainter old) => old.events != events || old.lanes != lanes;
}

/// Confirmed 폐사 마리수 per day: bars, a lighter bar on top for ranges, and
/// '?' for records with no count (symterAI DeathChart).
class _DeathChart extends StatelessWidget {
  const _DeathChart({required this.byDay, required this.from, required this.to});
  final List<Map<String, dynamic>> byDay;
  final String from;
  final String to;

  @override
  Widget build(BuildContext context) {
    final hasRange = byDay.any((d) => (d['max'] as int) > (d['min'] as int));
    final hasUnknown = byDay.any((d) => (d['unknown'] as int) > 0);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 200,
            width: double.infinity,
            child: CustomPaint(painter: _DeathPainter(byDay: byDay, from: _day(from), to: _day(to))),
          ),
          const SizedBox(height: 6),
          _Legend([
            ('확정된 폐사 마리수', kindColor('폐사'), false),
            if (hasRange) ('범위로 적힌 폐사(최대)', _deathLight, false),
            if (hasUnknown) ('? 수량 미기재 기록', kindColor('폐사'), true),
          ]),
        ],
      ),
    );
  }
}

class _DeathPainter extends CustomPainter {
  _DeathPainter({required this.byDay, required this.from, required this.to});
  final List<Map<String, dynamic>> byDay;
  final DateTime from;
  final DateTime to;

  @override
  void paint(Canvas canvas, Size size) {
    const top = 20.0, bottom = 24.0;
    final ax = _DayAxis(from, to, 36, 10, size.width);
    final peak = byDay.fold<int>(1, (m, d) => math.max(m, d['max'] as int));
    final step = math.max(1, (peak / 4).ceil());
    final hi = step * 4;
    double y(num v) => top + (hi - v) * (size.height - top - bottom) / hi;
    final bw = math.min(16.0, (size.width - ax.left - ax.right) / ax.days * 0.7).clamp(4.0, 16.0);

    final gridPaint = Paint()..color = _grid;
    for (var i = 0; i <= 4; i++) {
      final v = step * i;
      canvas.drawLine(Offset(ax.left, y(v)), Offset(size.width - ax.right, y(v)), gridPaint);
      _text(canvas, _fmtNum.format(v), Offset(ax.left - 6, y(v)), align: TextAlign.right);
    }
    final death = kindColor('폐사');
    for (final d in byDay) {
      final cx = ax.x(_day(d['date'] as String));
      final min = d['min'] as int, max = d['max'] as int, unknown = d['unknown'] as int;
      if (max > min) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTRB(cx - bw / 2, y(max), cx + bw / 2, y(min)), const Radius.circular(3)),
          Paint()..color = _deathLight,
        );
      }
      if (min > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTRB(cx - bw / 2, y(min), cx + bw / 2, y(0)), const Radius.circular(3)),
          Paint()..color = death,
        );
      }
      if (max > 0) {
        _text(canvas, max > min ? '$min~$max' : '$max', Offset(cx, y(max) - 9),
            size: 10.5, color: AppColors.textPrimary, align: TextAlign.center, weight: FontWeight.w700);
      }
      if (unknown > 0) {
        final c = Offset(cx, y(0) - (max > 0 ? (y(0) - y(max)) + 22 : 11));
        canvas.drawCircle(c, 8, Paint()..color = Colors.white);
        canvas.drawCircle(c, 8, Paint()
          ..color = death
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
        _text(canvas, '?', c, size: 10, color: death, align: TextAlign.center, weight: FontWeight.w800);
      }
    }
    for (final (d, align) in ax.ticks) {
      _text(canvas, _DayAxis.label(d), Offset(ax.x(d), size.height - 8), align: align);
    }
  }

  @override
  bool shouldRepaint(_DeathPainter old) => old.byDay != byDay;
}

/// 후속 확인이 필요한 기록 — status chip + "MM-DD 주제 — 원문".
class _OpenItems extends StatelessWidget {
  const _OpenItems({required this.items});
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _Muted('후속 확인이 필요하다고 적힌 기록이 없습니다.');
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final o in items)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(color: AppColors.neutralCard, borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.warningTint, borderRadius: BorderRadius.circular(6)),
                    child: Text('${o['status']}',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.warningTintInk)),
                  ),
                  const SizedBox(height: 6),
                  Text('${(o['date'] as String).substring(5)} ${o['topic']} — ${o['text']}',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary, height: 1.5)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Where the 외부 관측 numbers came from — kept apart so they're never read
/// as the farm's own tank readings (symterAI PublicSource).
class _PublicSource extends StatelessWidget {
  const _PublicSource({required this.pub, required this.redTide});
  final Map<String, dynamic> pub;
  final Map<String, dynamic>? redTide;

  @override
  Widget build(BuildContext context) {
    final station = pub['station'] as Map<String, dynamic>?;
    final obs = pub['observation'] as Map<String, dynamic>?;
    final fetched = pub['fetchedAt'] as String?;
    final notConnected = ((pub['notConnected'] as List<dynamic>?) ?? []).cast<String>();
    final red = switch (redTide?['status']) {
      'found' => '${redTide!['reportDate']} 발표 · ${((redTide!['occurrences'] as List<dynamic>?) ?? []).join(', ').ifEmpty('세부 해역 정보 없음')}'
          ' (전국 해역 대상 속보)',
      'none' => '기간 중 발표된 속보 없음',
      _ => '조회 실패 — 사용하지 않음',
    };
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.neutralCard,
        border: const Border(left: BorderSide(color: AppColors.textTertiary, width: 3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('외부 관측 자료(공공데이터) — 양식장 수조 실측값이 아닙니다',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          _MetaTable(rows: [
            ('상태', obs != null ? '사용' : '수온 조회 실패 — 사용하지 않음'),
            ('제공 기관', '해양수산부 국립수산과학원'),
            ('데이터', '실시간 해양관측 수온 · 적조 속보'),
            if (station != null) ('관측소', '${station['name']}${station['code'] != null ? ' (${station['code']})' : ''}'),
            if (obs != null) ('관측 시각', '${obs['observedDate']} ${obs['observedTime']}'),
            ('적조 속보', red),
            if (fetched != null) ('조회 시각', DateFormat('yyyy년 M월 d일 HH:mm').format(DateTime.parse(fetched).toLocal())),
            if (notConnected.isNotEmpty) ('미연동', notConnected.join(', ')),
          ]),
        ],
      ),
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

class _OpinionSection extends StatelessWidget {
  const _OpinionSection({required this.report, this.onEdit});
  final AiReport report;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final r = report;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('전문가 최종 의견', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
            ),
            if (onEdit != null && !r.isConfirmed)
              TextButton(
                onPressed: onEdit,
                style: TextButton.styleFrom(minimumSize: const Size(44, 36), padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: Text(r.finalOpinion.isEmpty ? '의견 작성' : '의견 수정',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.brand)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (r.finalOpinion.isNotEmpty)
          Text(r.finalOpinion, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.6))
        else
          const Text('작성된 최종 의견이 없습니다.', style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
        const SizedBox(height: 10),
        if (!r.isConfirmed)
          const Text('아직 전문가가 확정하지 않은 초안입니다. 위 내용은 AI 초안이며 최종 판단이 아닙니다.',
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.45))
        else
          _MetaTable(rows: [
            ('승인', r.confirmedByName ?? ''),
            ('승인일', r.confirmedAt == null ? '-' : DateFormat('yyyy년 M월 d일').format(r.confirmedAt!.toLocal())),
            if (r.version > 0) ('리포트 판', '제${r.version}판'),
            ('전문가 수정', r.editedSections.isEmpty ? 'AI 초안을 수정 없이 승인함' : '${r.editedSections.join(', ')} 섹션을 전문가가 수정함'),
          ]),
      ],
    );
  }
}

/// 양식장 × 주제 — how many memos of each topic per farm (symterAI
/// TopicHeatmap); darker = more.
class _TopicMatrix extends StatelessWidget {
  const _TopicMatrix({required this.rows, required this.topics});
  final List<Map<String, dynamic>> rows;
  final List<String> topics;

  @override
  Widget build(BuildContext context) {
    final active = rows.where((x) => (x['memos'] as int? ?? 0) > 0).toList();
    final peak = active.fold<int>(1, (m, x) {
      final counts = (x['topicCounts'] as Map<String, dynamic>?) ?? const {};
      return counts.values.fold<int>(m, (a, v) => math.max(a, (v as num).toInt()));
    });
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(children: [
            const SizedBox(),
            for (final t in topics)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                child: Text(t, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
              ),
          ]),
          for (final x in active)
            TableRow(children: [
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 2, bottom: 2),
                child: Text('${x['name']}', style: const TextStyle(fontSize: 11.5, color: AppColors.textPrimary)),
              ),
              for (final t in topics)
                () {
                  final n = (((x['topicCounts'] as Map<String, dynamic>?) ?? const {})[t] as num?)?.toInt() ?? 0;
                  return Container(
                    margin: const EdgeInsets.all(1.5),
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: n == 0 ? AppColors.neutralCard : _topicColor.withValues(alpha: 0.18 + 0.72 * n / peak),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(n == 0 ? '' : '$n',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: n / peak > 0.5 ? Colors.white : AppColors.textPrimary)),
                  );
                }(),
            ]),
        ],
      ),
    );
  }
}
