import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/monthly_report.dart';

/// 캘린더에서 고른 날짜에 한 줄 기록을 추가한다. 검사는 종류 "기타"로,
/// 나머지는 [MonthlyEvent.custom] 기록으로 들어간다.
Future<MonthlyEvent?> showAddDayRecordSheet(
  BuildContext context, {
  required int day,
  required int month,
  required List<MonthlyFarm> farms,
}) {
  return _show(context, _AddDaySheet(day: day, month: month, farms: farms));
}

/// 검사 기록을 날짜·종류·대상·소견까지 채워서 추가한다.
Future<MonthlyEvent?> showAddExamSheet(
  BuildContext context, {
  required int month,
  required int daysInMonth,
  required int today,
  required List<MonthlyFarm> farms,
}) {
  return _show(context, _AddExamSheet(month: month, daysInMonth: daysInMonth, today: today, farms: farms));
}

Future<MonthlyEvent?> _show(BuildContext context, Widget sheet) {
  return showModalBottomSheet<MonthlyEvent>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.scrim,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: sheet,
    ),
  );
}

class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.title, required this.sub, required this.children, required this.onSubmit});

  final String title;
  final String sub;
  final List<Widget> children;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                    width: 36, height: 4, decoration: BoxDecoration(color: const Color(0xFFDCE3EC), borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
              const SizedBox(height: 16),
              for (final c in children) ...[c, const SizedBox(height: 10)],
              const SizedBox(height: 6),
              ElevatedButton(
                onPressed: onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('추가', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration _deco(String label, {String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      labelStyle: const TextStyle(fontSize: 12.5, color: AppColors.textTertiary),
      hintStyle: const TextStyle(fontSize: 12.5, color: AppColors.textFaint),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.brand)),
    );

const _fieldStyle = TextStyle(fontSize: 13, color: AppColors.textPrimary);

class _AddDaySheet extends StatefulWidget {
  const _AddDaySheet({required this.day, required this.month, required this.farms});

  final int day;
  final int month;
  final List<MonthlyFarm> farms;

  @override
  State<_AddDaySheet> createState() => _AddDaySheetState();
}

class _AddDaySheetState extends State<_AddDaySheet> {
  MonthlyEventType _type = MonthlyEventType.patrol;
  late String _farm = widget.farms.first.id;
  final _tank = TextEditingController();
  final _note = TextEditingController();
  String? _noteError;

  @override
  void dispose() {
    _tank.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final note = _note.text.trim();
    if (note.isEmpty) {
      setState(() => _noteError = '내용을 입력하세요');
      return;
    }
    final tank = _tank.text.trim();
    Navigator.of(context).pop(
      _type == MonthlyEventType.exam
          ? MonthlyEvent(day: widget.day, farm: _farm, type: _type, tank: tank, kind: '기타', subject: '', result: note)
          : MonthlyEvent(day: widget.day, farm: _farm, type: _type, tank: tank, note: note, custom: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: '${widget.month}/${widget.day} 기록 추가',
      sub: '관리원 내부 기록 · 월별 리포트 캘린더에 표시됩니다',
      onSubmit: _submit,
      children: [
        DropdownButtonFormField<MonthlyEventType>(
          initialValue: _type,
          decoration: _deco('종류'),
          style: _fieldStyle,
          items: [for (final t in MonthlyEventType.addable) DropdownMenuItem(value: t, child: Text(t.label))],
          onChanged: (v) => setState(() => _type = v ?? _type),
        ),
        DropdownButtonFormField<String>(
          initialValue: _farm,
          decoration: _deco('양식장'),
          style: _fieldStyle,
          items: [for (final f in widget.farms) DropdownMenuItem(value: f.id, child: Text(f.id))],
          onChanged: (v) => setState(() => _farm = v ?? _farm),
        ),
        TextField(controller: _tank, style: _fieldStyle, decoration: _deco('수조', hint: '예: 1동-01')),
        TextField(
          controller: _note,
          style: _fieldStyle,
          maxLines: 2,
          decoration: _deco('내용').copyWith(errorText: _noteError),
          onChanged: (_) => _noteError == null ? null : setState(() => _noteError = null),
        ),
      ],
    );
  }
}

class _AddExamSheet extends StatefulWidget {
  const _AddExamSheet({required this.month, required this.daysInMonth, required this.today, required this.farms});

  final int month;
  final int daysInMonth;
  final int today;
  final List<MonthlyFarm> farms;

  @override
  State<_AddExamSheet> createState() => _AddExamSheetState();
}

class _AddExamSheetState extends State<_AddExamSheet> {
  static const _kinds = ['입식', '질병', '정기', '폐사 원인', '출하 전'];
  static const _custom = '직접 입력';

  late int _day = widget.today;
  late String _farm = widget.farms.first.id;
  String _kind = _kinds.first;
  final _customKind = TextEditingController();
  final _tank = TextEditingController();
  final _subject = TextEditingController();
  final _result = TextEditingController();

  @override
  void dispose() {
    for (final c in [_customKind, _tank, _subject, _result]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final customKind = _customKind.text.trim();
    Navigator.of(context).pop(MonthlyEvent(
      day: _day,
      farm: _farm,
      type: MonthlyEventType.exam,
      kind: _kind == _custom ? (customKind.isEmpty ? '기타' : customKind) : _kind,
      tank: _tank.text.trim(),
      subject: _subject.text.trim(),
      result: _result.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      title: '검사 추가',
      sub: '입식·질병·정기·폐사 원인 등 종류별로 기록합니다',
      onSubmit: _submit,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _day,
                decoration: _deco('날짜'),
                style: _fieldStyle,
                menuMaxHeight: 320,
                items: [
                  for (var d = 1; d <= widget.daysInMonth; d++) DropdownMenuItem(value: d, child: Text('${widget.month}/$d')),
                ],
                onChanged: (v) => setState(() => _day = v ?? _day),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _farm,
                decoration: _deco('양식장'),
                style: _fieldStyle,
                items: [for (final f in widget.farms) DropdownMenuItem(value: f.id, child: Text(f.id))],
                onChanged: (v) => setState(() => _farm = v ?? _farm),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _kind,
                decoration: _deco('검사 종류'),
                style: _fieldStyle,
                items: [for (final k in [..._kinds, _custom]) DropdownMenuItem(value: k, child: Text(k))],
                onChanged: (v) => setState(() => _kind = v ?? _kind),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _tank, style: _fieldStyle, decoration: _deco('수조', hint: '예: 1동-01'))),
          ],
        ),
        if (_kind == _custom) TextField(controller: _customKind, style: _fieldStyle, decoration: _deco('검사 종류 직접 입력')),
        TextField(controller: _subject, style: _fieldStyle, decoration: _deco('대상', hint: '품종·마릿수')),
        TextField(controller: _result, style: _fieldStyle, maxLines: 2, decoration: _deco('소견·결과')),
      ],
    );
  }
}
