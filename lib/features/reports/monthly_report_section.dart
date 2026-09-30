import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/monthly_report.dart';
import 'monthly_report_charts.dart';
import 'monthly_report_sheets.dart';

const _dow = ['일', '월', '화', '수', '목', '금', '토'];
const _crit = Color(0xFFD03B3B);

String _won(int n) => '${NumberFormat('#,###').format(n)}원';
String _f1(double v) => v.toStringAsFixed(1);

/// 전체 리포트 상단의 "수산질병관리원 월별 리포트". 기관 내부에서만 보는
/// 화면이라 어가 공유 기능은 없다. 캘린더·검사에서 추가한 기록은 화면을
/// 벗어나면 사라진다(아직 저장 API 없음).
class MonthlyReportSection extends StatefulWidget {
  const MonthlyReportSection({super.key, required this.report});

  final MonthlyReport report;

  @override
  State<MonthlyReportSection> createState() => _MonthlyReportSectionState();
}

enum _MemoTab {
  delivery('배달', '약품, 비타민제 등'),
  exam('검사', '입식·질병·정기·폐사 원인 등 종류별 기록'),
  diag('바이러스 진단', '바이러스 검사 + 현미경 관찰'),
  safety('안전성 검사', '체내 항생제 잔류'),
  water('수조 DO·pH', '기준: DO 5 mg/L 이상, pH 7.5~8.5'),
  vacc('접종', '마릿수, 수조명');

  const _MemoTab(this.label, this.sub);
  final String label;
  final String sub;
}

class _MonthlyReportSectionState extends State<MonthlyReportSection> {
  late final List<MonthlyEvent> _records = [...widget.report.events];
  late int _selDay = widget.report.today;
  late String _selTank = widget.report.tanks
      .firstWhere((t) => t.farm.startsWith('진도'), orElse: () => widget.report.tanks.first)
      .key;
  String? _openFarm;
  bool _showSalinity = false;
  _MemoTab _tab = _MemoTab.delivery;
  String _examKind = '전체';

  MonthlyReport get r => widget.report;
  List<MonthlyEvent> get _events => r.allEvents(_records);

  String _dstr(int d) => '${r.month}/$d (${_dow[DateTime(r.year, r.month, d).weekday % 7]})';

  List<MonthlyEvent> _byDay(int d) => _events.where((e) => e.day == d).toList()
    ..sort((a, b) => MonthlyEventType.displayOrder.indexOf(a.type).compareTo(MonthlyEventType.displayOrder.indexOf(b.type)));

  String _describe(MonthlyEvent e) {
    if (e.custom) return [e.tank, e.note].where((s) => s != null && s.isNotEmpty).join(' · ');
    return switch (e.type) {
      MonthlyEventType.patrol => [e.tank, e.note].where((s) => s != null && s.isNotEmpty).join(' · '),
      MonthlyEventType.delivery =>
        '${e.item} ${e.qty} · ${_won(e.amount ?? 0)} · ${e.isPendingDelivery ? '배달 예정(금액 미정)' : '배달 완료'}',
      MonthlyEventType.diag => '${e.tank} · ${e.test} ${e.result} · 현미경: ${e.micro} · ${e.disease}',
      MonthlyEventType.exam =>
        '[${e.kind}] ${[e.tank, e.subject, e.result].where((s) => s != null && s.isNotEmpty).join(' · ')}',
      MonthlyEventType.safety => '${e.tank} · ${e.drug} ${e.result}${(e.note ?? '').isEmpty ? '' : ' · ${e.note}'}',
      MonthlyEventType.vacc =>
        '${e.tank} · ${e.drug} ${NumberFormat('#,###').format(e.count ?? 0)}마리 · ${_won(e.fee ?? 0)} · ${e.status}',
      MonthlyEventType.water =>
        '${e.tank} · DO ${_f1(e.doValue!)} · pH ${_f1(e.ph!)} · ${isWaterOk(e.doValue!, e.ph!) ? '정상' : '기준 밖'}',
    };
  }

  void _addRecord(MonthlyEvent e) => setState(() {
        _records.add(e);
        _selDay = e.day;
      });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        const SizedBox(height: 12),
        _seaCard(),
        const SizedBox(height: 12),
        _kpis(),
        const SizedBox(height: 12),
        _calendarCard(),
        const SizedBox(height: 12),
        _boardCard(),
        const SizedBox(height: 12),
        _memoCard(),
      ],
    );
  }

  // ---- 머리말 ----
  Widget _header() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.brandTint, borderRadius: BorderRadius.circular(20)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, size: 11, color: AppColors.brand),
                    SizedBox(width: 3),
                    Text('관리원 내부 공유', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.brand)),
                  ],
                ),
              ),
              const Spacer(),
              const Text('어가에는 공유되지 않습니다', style: TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 10),
          const Text('수산질병관리원 월별 리포트',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -.3)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFFFE49B), borderRadius: BorderRadius.circular(20)),
            child: Text('${r.year}년 ${r.month}월 · 기준일 ${r.month}/${r.today} · 양식장 ${r.farms.length}곳 · 예시 데이터',
                style: const TextStyle(fontSize: 11, color: Color(0xFF5A4300))),
          ),
        ],
      ),
    );
  }

  // ---- 수온·염도 ----
  Widget _seaCard() {
    final seas = r.sea.entries.toList();
    final dT = [for (final s in seas) s.value.temps.first - s.value.temps.last];
    final dS = [for (final s in seas) s.value.salinities.last - s.value.salinities.first];
    String range(List<double> v) =>
        '${v.reduce((a, b) => a < b ? a : b).toStringAsFixed(1)}~${v.reduce((a, b) => a > b ? a : b).toStringAsFixed(1)}';

    return _Card(
      title: '수온·염도',
      sub: '${r.month}월 한 달, 해역별 주간 값',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Toggle(label: '수온 °C', on: !_showSalinity, onTap: () => setState(() => _showSalinity = false)),
              const SizedBox(width: 6),
              _Toggle(label: '염도 psu', on: _showSalinity, onTap: () => setState(() => _showSalinity = true)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              for (var k = 0; k < r.weeks.length; k++)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 9, height: 9, decoration: BoxDecoration(color: weekRamp[k], borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 4),
                  Text('${r.month}/${r.weeks[k]}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ]),
            ],
          ),
          const SizedBox(height: 8),
          SeaBarChart(
            groups: {
              for (final s in seas)
                s.key: (
                  _showSalinity ? s.value.salinities : s.value.temps,
                  r.farms.where((f) => f.sea == s.key).length,
                ),
            },
            top: _showSalinity ? 40 : 30,
            step: 5,
          ),
          const SizedBox(height: 8),
          Text(
            '한 달 동안 수온은 모든 해역에서 ${range(dT)}°C 내려갔고, 염도는 ${range(dS)} psu 올라 거의 변화가 없었습니다. '
            '숫자는 ${r.month}/${r.weeks.first}과 ${r.month}/${r.weeks.last} 값입니다.',
            style: const TextStyle(fontSize: 11.5, height: 1.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          const Align(
            alignment: Alignment.centerRight,
            child: Text('출처: 공공 해양관측 서비스 (예시 데이터)', style: TextStyle(fontSize: 9.5, color: AppColors.textMuted)),
          ),
        ],
      ),
    );
  }

  // ---- KPI ----
  Widget _kpis() {
    final events = _events;
    Widget tile(String label, int n, String unit, Color bg, Color fg) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              border: bg == AppColors.surface ? Border.all(color: AppColors.border) : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
                const SizedBox(height: 2),
                Text.rich(TextSpan(children: [
                  TextSpan(text: '$n', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: fg)),
                  TextSpan(text: ' $unit', style: TextStyle(fontSize: 11, color: fg)),
                ])),
              ],
            ),
          ),
        );
    return Column(
      children: [
        Row(children: [
          tile('긴급 양식장', r.farms.where((f) => f.status == MonthlyFarmStatus.urgent).length, '곳', AppColors.dangerTint,
              AppColors.dangerDark),
          const SizedBox(width: 8),
          tile('조치 필요 양식장', r.farms.where((f) => f.status == MonthlyFarmStatus.action).length, '곳', AppColors.warningTint,
              AppColors.warningTintInk),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          tile('검사 결과 대기', events.where((e) => e.type == MonthlyEventType.safety && e.result == '검사 중').length, '건',
              AppColors.surface, AppColors.textPrimary),
          const SizedBox(width: 8),
          tile('이번 달 기록', events.where((e) => e.day <= r.today).length, '건', AppColors.surface, AppColors.textPrimary),
        ]),
      ],
    );
  }

  // ---- 캘린더 ----
  Widget _calendarCard() {
    final first = DateTime(r.year, r.month, 1).weekday % 7;
    final cells = <Widget>[
      for (var i = 0; i < first; i++) const SizedBox.shrink(),
      for (var d = 1; d <= r.daysInMonth; d++) _dayCell(d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox.shrink());
    }

    return _Card(
      title: '${r.month}월 업무 캘린더',
      sub: '예찰·배달·진단·검사·접종 기록. 날짜를 누르면 그날 내용이 열립니다.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (final t in MonthlyEventType.values) TypeChip(type: t),
              const TypeChip(label: '테두리만 = 예정', color: AppColors.textMuted, planned: true),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(_dow[i],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: i == 0 ? _crit : i == 6 ? MonthlyEventType.patrol.color : AppColors.textSecondary,
                        )),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var row = 0; row < cells.length ~/ 7; row++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  for (var c = 0; c < 7; c++) ...[
                    if (c > 0) const SizedBox(width: 4),
                    Expanded(child: SizedBox(height: 58, child: cells[row * 7 + c])),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 6),
          _dayPanel(),
        ],
      ),
    );
  }

  Widget _dayCell(int d) {
    final evs = _byDay(d);
    final main = evs.where((e) => e.type != MonthlyEventType.water).toList();
    final waterCount = evs.length - main.length;
    final dots = [
      for (final e in main) (e.type.color, r.isPlanned(e)),
      if (waterCount > 0) (MonthlyEventType.water.color, false),
    ];
    const maxDots = 6;
    final wd = DateTime(r.year, r.month, d).weekday % 7;
    final isToday = d == r.today, isSel = d == _selDay;

    return Material(
      color: isToday ? const Color(0xFFEEF8F8) : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(7),
        side: BorderSide(
          color: isSel ? AppColors.textPrimary : isToday ? const Color(0xFF3F9AA5) : AppColors.border,
          width: isSel || isToday ? 1.6 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: () => setState(() => _selDay = d),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$d',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: wd == 0 ? _crit : wd == 6 ? MonthlyEventType.patrol.color : AppColors.textPrimary,
                  )),
              const SizedBox(height: 3),
              Wrap(
                spacing: 2.5,
                runSpacing: 2.5,
                children: [
                  for (final (color, planned) in dots.take(maxDots))
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: planned ? Colors.transparent : color,
                        border: Border.all(color: color, width: 1.2),
                      ),
                    ),
                ],
              ),
              if (dots.length > maxDots)
                Text('+${dots.length - maxDots}', style: const TextStyle(fontSize: 8.5, color: AppColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dayPanel() {
    final evs = _byDay(_selDay);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.neutralCard,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${_dstr(_selDay)} · ${evs.length}건',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              ),
              _SmallButton(
                label: '$_selDay일에 추가',
                onTap: () async {
                  final e = await showAddDayRecordSheet(context, day: _selDay, month: r.month, farms: r.farms);
                  if (e != null) _addRecord(e);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (evs.isEmpty)
            const Text('기록이 없습니다. 오른쪽 위에서 추가하세요.', style: TextStyle(fontSize: 12, color: AppColors.textMuted))
          else
            for (final e in evs)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 78, child: Align(alignment: Alignment.topLeft, child: TypeChip(type: e.type, planned: r.isPlanned(e)))),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(text: e.farm, style: const TextStyle(fontWeight: FontWeight.w700)),
                          TextSpan(text: ' · ${_describe(e)}'),
                        ]),
                        style: const TextStyle(fontSize: 12, height: 1.45, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  // ---- 현황판 ----
  MonthlyEvent? _latest(String farm, MonthlyEventType type) {
    final list = _events.where((e) => e.farm == farm && e.type == type && e.day <= r.today && !e.custom).toList()
      ..sort((a, b) => b.day.compareTo(a.day));
    return list.isEmpty ? null : list.first;
  }

  Widget _boardCard() {
    return _Card(
      title: '양식장 현황판',
      sub: '양식장을 누르면 ${r.month}월 동안 진행한 내용이 모두 보입니다.',
      child: Column(
        children: [
          for (var i = 0; i < r.farms.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _boardRow(r.farms[i]),
          ],
        ],
      ),
    );
  }

  Widget _boardRow(MonthlyFarm f) {
    final open = _openFarm == f.id;
    final sea = r.sea[f.sea]!;
    final w = _latest(f.id, MonthlyEventType.water);
    final dg = _latest(f.id, MonthlyEventType.diag);
    final sf = _latest(f.id, MonthlyEventType.safety);
    final vcList = _events.where((e) => e.farm == f.id && e.type == MonthlyEventType.vacc && !e.custom).toList()
      ..sort((a, b) => b.day.compareTo(a.day));
    final vc = vcList.isEmpty ? null : vcList.first;
    const none = _Kv.none;

    return Container(
      decoration: BoxDecoration(
        color: open ? const Color(0xFFF5FAFA) : AppColors.surface,
        border: Border.all(color: open ? const Color(0xFF8FB9C2) : AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _openFarm = open ? null : f.id),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(open ? Icons.expand_more : Icons.chevron_right, size: 18, color: AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Text(f.id, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      const SizedBox(width: 6),
                      Text('${f.sea} · ${f.fish}', style: const TextStyle(fontSize: 11.5, color: AppColors.textTertiary)),
                      const Spacer(),
                      StatusPill(status: f.status),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(builder: (context, c) {
                    final half = (c.maxWidth - 10) / 2;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        for (final kv in [
                          _Kv('수온·염도', '${_f1(sea.temps.last)}°C / ${_f1(sea.salinities.last)} psu'),
                          w == null
                              ? const _Kv('DO·pH', none)
                              : _Kv('DO·pH', 'DO ${_f1(w.doValue!)} · pH ${_f1(w.ph!)}',
                                  sub: '${r.month}/${w.day}, ${w.tank}', bad: !isWaterOk(w.doValue!, w.ph!)),
                          dg == null
                              ? const _Kv('진단 (바이러스)', none)
                              : _Kv('진단 (바이러스)', '${dg.test} ${dg.result} · ${dg.disease}',
                                  sub: '${r.month}/${dg.day}, ${dg.tank}', bad: dg.result == '양성'),
                          sf == null
                              ? const _Kv('안전성 검사', none)
                              : _Kv('안전성 검사', sf.result ?? '', sub: '${r.month}/${sf.day}, ${sf.tank}', bad: sf.result == '검출'),
                          vc == null
                              ? const _Kv('접종', none)
                              : _Kv('접종', '${vc.day > r.today ? '예정' : '완료'} ${r.month}/${vc.day}', sub: vc.tank),
                          _Kv('다음 일정', f.next),
                        ])
                          SizedBox(width: half, child: kv),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
          if (open) _farmTimeline(f),
        ],
      ),
    );
  }

  Widget _farmTimeline(MonthlyFarm f) {
    final evs = _events.where((e) => e.farm == f.id).toList()
      ..sort((a, b) {
        final byDay = a.day.compareTo(b.day);
        if (byDay != 0) return byDay;
        return MonthlyEventType.displayOrder.indexOf(a.type).compareTo(MonthlyEventType.displayOrder.indexOf(b.type));
      });
    final counts = [
      for (final t in MonthlyEventType.values)
        if (evs.any((e) => e.type == t)) (t, evs.where((e) => e.type == t).length),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${f.id} · ${r.month}월 진행 내용 ${evs.length}건',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Wrap(spacing: 5, runSpacing: 5, children: [
            for (final (t, n) in counts) TypeChip(type: t, label: '${t.label} $n'),
          ]),
          const SizedBox(height: 10),
          if (evs.isEmpty)
            Text('${r.month}월 기록이 없습니다.', style: const TextStyle(fontSize: 12, color: AppColors.textMuted))
          else
            for (var i = 0; i < evs.length; i++)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 14,
                      child: Stack(alignment: Alignment.topCenter, children: [
                        if (i < evs.length - 1)
                          Positioned(top: 6, bottom: 0, child: Container(width: 2, color: AppColors.border)),
                        Container(
                          margin: const EdgeInsets.only(top: 3),
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: evs[i].type.color, width: 2),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text(_dstr(evs[i].day), style: const TextStyle(fontSize: 11.5, color: AppColors.textTertiary)),
                              const SizedBox(width: 6),
                              TypeChip(type: evs[i].type, planned: r.isPlanned(evs[i])),
                            ]),
                            const SizedBox(height: 3),
                            Text(_describe(evs[i]), style: const TextStyle(fontSize: 12, height: 1.45, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  // ---- 메모 기록 ----
  Widget _memoCard() {
    final del = _typed(MonthlyEventType.delivery);
    final vac = _typed(MonthlyEventType.vacc);
    final dDone = del.where((e) => !e.isPendingDelivery).fold<int>(0, (s, e) => s + (e.amount ?? 0));
    final dPend = del.where((e) => e.isPendingDelivery).fold<int>(0, (s, e) => s + (e.amount ?? 0));
    final vDone = vac.where((e) => e.status == '정산 완료').fold<int>(0, (s, e) => s + (e.fee ?? 0));
    final vPend = vac.where((e) => e.status != '정산 완료').fold<int>(0, (s, e) => s + (e.fee ?? 0));

    Widget cost(String label, int done, String pendLabel, int pend) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textTertiary))),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_won(done), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                Text('+ $pendLabel ${_won(pend)}', style: const TextStyle(fontSize: 10.5, color: AppColors.textTertiary)),
              ]),
            ],
          ),
        );

    return _Card(
      title: '메모 기록',
      sub: '${r.month}월 기록',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          cost('약품 배달', dDone, '미정', dPend),
          const SizedBox(height: 6),
          cost('접종비', vDone, '정산 전', vPend),
          const SizedBox(height: 6),
          cost('합계', dDone + vDone, '미정·정산 전', dPend + vPend),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final t in _MemoTab.values) ...[
                _Toggle(label: t.label, on: _tab == t, onTap: () => setState(() => _tab = t)),
                const SizedBox(width: 6),
              ],
            ]),
          ),
          const SizedBox(height: 8),
          Text(_tab.sub, style: const TextStyle(fontSize: 11.5, color: AppColors.textTertiary)),
          const SizedBox(height: 8),
          switch (_tab) {
            _MemoTab.delivery => _deliveryList(del),
            _MemoTab.exam => _examList(),
            _MemoTab.diag => _diagList(),
            _MemoTab.safety => _safetyList(),
            _MemoTab.water => _waterView(),
            _MemoTab.vacc => _vaccList(vac),
          },
        ],
      ),
    );
  }

  /// 표에 들어가는 정식 기록 (캘린더에서 한 줄로 추가한 기록 제외), 최신순.
  List<MonthlyEvent> _typed(MonthlyEventType t) =>
      _records.where((e) => e.type == t && !e.custom).toList()..sort((a, b) => b.day.compareTo(a.day));

  Widget _list(List<Widget> tiles, {String empty = '기록이 없습니다.'}) => tiles.isEmpty
      ? Padding(padding: const EdgeInsets.all(8), child: Text(empty, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)))
      : Column(children: [
          for (var i = 0; i < tiles.length; i++) ...[if (i > 0) const SizedBox(height: 6), tiles[i]],
        ]);

  Widget _deliveryList(List<MonthlyEvent> del) => _list([
        for (final e in del)
          _RecordTile(
            date: '${r.month}/${e.day}',
            title: '${e.farm} · ${e.item} ${e.qty}',
            lines: [_won(e.amount ?? 0)],
            trailing: _Pill(e.isPendingDelivery ? '배달 예정' : '배달 완료', e.isPendingDelivery ? _PillTone.wait : _PillTone.ok),
          ),
      ]);

  Widget _examList() {
    final exams = _typed(MonthlyEventType.exam);
    final kinds = ['전체', ...{for (final e in exams) e.kind ?? '기타'}];
    final shown = exams.where((e) => _examKind == '전체' || e.kind == _examKind).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final k in kinds) ...[
                    _Toggle(
                      label: '$k ${k == '전체' ? exams.length : exams.where((e) => e.kind == k).length}',
                      on: _examKind == k,
                      small: true,
                      onTap: () => setState(() => _examKind = k),
                    ),
                    const SizedBox(width: 5),
                  ],
                ]),
              ),
            ),
            const SizedBox(width: 6),
            _SmallButton(
              label: '검사 추가',
              onTap: () async {
                final e = await showAddExamSheet(context, month: r.month, daysInMonth: r.daysInMonth, today: r.today, farms: r.farms);
                if (e != null) _addRecord(e);
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        _list([
          for (final e in shown)
            _RecordTile(
              date: '${r.month}/${e.day}',
              title: '${e.farm} · ${(e.tank ?? '').isEmpty ? '-' : e.tank}',
              badge: TypeChip(type: MonthlyEventType.exam, label: e.kind ?? '기타'),
              lines: [
                if ((e.subject ?? '').isNotEmpty) '대상: ${e.subject}',
                if ((e.result ?? '').isNotEmpty) '소견: ${e.result}',
              ],
            ),
        ]),
      ],
    );
  }

  Widget _diagList() => _list([
        for (final e in _typed(MonthlyEventType.diag))
          _RecordTile(
            date: '${r.month}/${e.day}',
            title: '${e.farm} · ${e.tank}',
            lines: ['현미경: ${e.micro}', '병명: ${e.disease}'],
            trailing: Text('${e.test} ${e.result}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: e.result == '양성' ? _crit : AppColors.textPrimary,
                )),
          ),
      ]);

  Widget _safetyList() => _list([
        for (final e in _typed(MonthlyEventType.safety))
          _RecordTile(
            date: '${r.month}/${e.day}',
            title: '${e.farm} · ${e.tank}',
            lines: ['검사 약품: ${e.drug}', if ((e.note ?? '').isNotEmpty) '비고: ${e.note}'],
            trailing: Text(e.result ?? '',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: e.result == '검출' ? _crit : AppColors.textPrimary)),
          ),
      ]);

  Widget _vaccList(List<MonthlyEvent> vac) => _list([
        for (final e in vac)
          _RecordTile(
            date: '${r.month}/${e.day}',
            planned: e.day > r.today,
            title: '${e.farm} · ${e.tank}',
            lines: ['${e.drug} · ${NumberFormat('#,###').format(e.count ?? 0)}마리', '접종비 ${_won(e.fee ?? 0)}'],
            trailing: _Pill(e.status ?? '', e.status == '정산 완료' ? _PillTone.ok : _PillTone.wait),
          ),
      ]);

  Widget _waterView() {
    final tank = r.tanks.firstWhere((t) => t.key == _selTank);
    final bad = [
      for (var i = 0; i < tank.days.length; i++)
        if (!isWaterOk(tank.doValues[i], tank.phValues[i])) tank.days[i],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final t in r.tanks) ...[
          _waterTankTile(t),
          const SizedBox(height: 6),
        ],
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${tank.farm} · ${tank.tank} · ${r.month}월 DO·pH',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: '${tank.days.length}회 측정 (${r.month}/${tank.days.first} ~ ${r.month}/${tank.days.last}) · '),
                  bad.isEmpty
                      ? const TextSpan(text: '모두 기준 안')
                      : TextSpan(
                          text: '기준 밖 ${bad.length}회 (${r.month}/${bad.first}부터)',
                          style: const TextStyle(color: _crit, fontWeight: FontWeight.w700)),
                ]),
                style: const TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
              ),
              const SizedBox(height: 12),
              const Text('DO (mg/L)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ThresholdLineChart(days: tank.days, values: tank.doValues, min: 0, max: 10, step: 2, lo: 5, isOk: isDoOk),
              const SizedBox(height: 8),
              const Text('pH', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ThresholdLineChart(
                  days: tank.days, values: tank.phValues, min: 7, max: 9, step: .5, lo: 7.5, hi: 8.5, isOk: isPhOk),
              const SizedBox(height: 10),
              _waterTable(tank),
            ],
          ),
        ),
      ],
    );
  }

  Widget _waterTankTile(WaterTank t) {
    final sel = t.key == _selTank;
    final n = t.days.length - 1;
    final doV = t.doValues[n], ph = t.phValues[n];
    final ok = isWaterOk(doV, ph);
    return Material(
      color: sel ? const Color(0xFFEEF8F8) : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: sel ? const Color(0xFF8FB9C2) : AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _selTank = t.key),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${t.farm} · ${t.tank}',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: '${t.days.length}회 · 최근 ${r.month}/${t.days[n]} · '),
                        TextSpan(text: 'DO ${_f1(doV)}', style: TextStyle(color: isDoOk(doV) ? null : _crit, fontWeight: isDoOk(doV) ? null : FontWeight.w700)),
                        const TextSpan(text: ' · '),
                        TextSpan(text: 'pH ${_f1(ph)}', style: TextStyle(color: isPhOk(ph) ? null : _crit, fontWeight: isPhOk(ph) ? null : FontWeight.w700)),
                      ]),
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              _Pill(ok ? '정상' : '⚠ 기준 밖', ok ? _PillTone.ok : _PillTone.urgent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _waterTable(WaterTank t) {
    const head = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary);
    const cell = TextStyle(fontSize: 11.5, color: AppColors.textPrimary);
    const badCell = TextStyle(fontSize: 11.5, color: _crit, fontWeight: FontWeight.w700);
    Widget c(String s, TextStyle style, {Color? bg}) => Container(
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(s, style: style),
        );
    const headBg = Color(0xFFDCEFEE);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: const TableBorder(horizontalInside: BorderSide(color: Color(0xFFE6ECEE))),
          children: [
            TableRow(children: [c('측정일', head, bg: headBg), for (final d in t.days) c(_dstr(d), head, bg: headBg)]),
            TableRow(children: [
              c('DO', head),
              for (final v in t.doValues) c(_f1(v), isDoOk(v) ? cell : badCell),
            ]),
            TableRow(children: [
              c('pH', head),
              for (final v in t.phValues) c(_f1(v), isPhOk(v) ? cell : badCell),
            ]),
            TableRow(children: [
              c('판정', head),
              for (var i = 0; i < t.days.length; i++)
                isWaterOk(t.doValues[i], t.phValues[i]) ? c('정상', cell) : c('기준 밖', badCell),
            ]),
          ],
        ),
      ),
    );
  }
}

// ---- 작은 위젯들 ----

class _Card extends StatelessWidget {
  const _Card({required this.child, this.title, this.sub});

  final Widget child;
  final String? title;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(title!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            if (sub != null) ...[
              const SizedBox(height: 2),
              Text(sub!, style: const TextStyle(fontSize: 11.5, height: 1.4, color: AppColors.textTertiary)),
            ],
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

/// 업무 종류 칩. 왼쪽 굵은 색 선 + 옅은 배경, 예정이면 흰 바탕 + 점선 대신
/// 얇은 테두리.
class TypeChip extends StatelessWidget {
  const TypeChip({super.key, this.type, this.label, this.color, this.planned = false})
      : assert(type != null || (label != null && color != null));

  final MonthlyEventType? type;
  final String? label;
  final Color? color;
  final bool planned;

  @override
  Widget build(BuildContext context) {
    final c = color ?? type!.color;
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 2, 6, 2),
      decoration: BoxDecoration(
        color: planned ? Colors.white : Color.alphaBlend(c.withValues(alpha: .13), Colors.white),
        border: Border(
          left: BorderSide(color: c, width: 3),
          top: planned ? BorderSide(color: c, width: .8) : BorderSide.none,
          right: planned ? BorderSide(color: c, width: .8) : BorderSide.none,
          bottom: planned ? BorderSide(color: c, width: .8) : BorderSide.none,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(label ?? type!.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10.5, height: 1.3, color: AppColors.textPrimary)),
          ),
          if (planned && type != null) ...[
            const SizedBox(width: 3),
            const Text('예정', style: TextStyle(fontSize: 9.5, color: AppColors.textMuted)),
          ],
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});

  final MonthlyFarmStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      MonthlyFarmStatus.urgent => const _Pill('⚠ 긴급', _PillTone.urgent),
      MonthlyFarmStatus.action => const _Pill('조치 필요', _PillTone.action),
      MonthlyFarmStatus.normal => const _Pill('정상', _PillTone.ok),
    };
  }
}

enum _PillTone {
  urgent(Color(0xFFF7C4B8), Color(0xFF7A1F14)),
  action(Color(0xFFFFE49B), Color(0xFF5A4300)),
  ok(Color(0xFFCFEEDD), Color(0xFF135C32)),
  wait(Color(0xFFE4DDF6), Color(0xFF3B2E86));

  const _PillTone(this.bg, this.fg);
  final Color bg;
  final Color fg;
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.tone);

  final String text;
  final _PillTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: tone.fg)),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.label, required this.on, required this.onTap, this.small = false});

  final String label;
  final bool on;
  final VoidCallback onTap;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: on ? AppColors.textPrimary : AppColors.surface,
      shape: StadiumBorder(side: BorderSide(color: on ? AppColors.textPrimary : AppColors.borderStrong)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: small ? 9 : 12, vertical: small ? 4 : 6),
          child: Text(label,
              style: TextStyle(
                fontSize: small ? 11 : 12,
                fontWeight: FontWeight.w700,
                color: on ? Colors.white : AppColors.textSecondary,
              )),
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brand,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.add, size: 14, color: Colors.white),
            const SizedBox(width: 3),
            Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
          ]),
        ),
      ),
    );
  }
}

class _Kv extends StatelessWidget {
  const _Kv(this.label, this.value, {this.sub, this.bad = false});

  static const none = '기록 없음';

  final String label;
  final String value;
  final String? sub;
  final bool bad;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
        const SizedBox(height: 1),
        Text(value,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              fontWeight: bad ? FontWeight.w700 : FontWeight.w500,
              color: bad ? _crit : value == none ? AppColors.textFaint : AppColors.textPrimary,
            )),
        if (sub != null) Text(sub!, style: const TextStyle(fontSize: 10.5, color: AppColors.textTertiary)),
      ],
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.date, required this.title, this.lines = const [], this.trailing, this.badge, this.planned = false});

  final String date;
  final String title;
  final List<String> lines;
  final Widget? trailing;
  final Widget? badge;
  final bool planned;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(date, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              if (planned) const Text('예정', style: TextStyle(fontSize: 9.5, color: AppColors.textMuted)),
            ]),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  ),
                  if (badge != null) ...[const SizedBox(width: 6), badge!],
                ]),
                for (final l in lines) ...[
                  const SizedBox(height: 2),
                  Text(l, style: const TextStyle(fontSize: 11.5, height: 1.4, color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}
