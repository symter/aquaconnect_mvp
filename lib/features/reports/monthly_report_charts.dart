import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 주차별 색 (옅은 파랑 → 진한 파랑). 월별 리포트 HTML의 `RAMP`.
const weekRamp = [Color(0xFF86B6EF), Color(0xFF5598E7), Color(0xFF2A78D6), Color(0xFF1C5CAB), Color(0xFF0D366B)];

const _grid = Color(0xFFE6ECEE);
const _axis = Color(0xFFB9C3C6);
const _crit = Color(0xFFD03B3B);
const _ok = Color(0xFF1F8A4C);
const _line = Color(0xFF2A78D6);

void _text(Canvas canvas, String s, Offset at,
    {double size = 10, Color color = AppColors.textMuted, FontWeight weight = FontWeight.w400, TextAlign align = TextAlign.center}) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: TextStyle(fontSize: size, color: color, fontWeight: weight)),
    textDirection: TextDirection.ltr,
  )..layout();
  final dx = switch (align) {
    TextAlign.right || TextAlign.end => at.dx - tp.width,
    TextAlign.left || TextAlign.start => at.dx,
    _ => at.dx - tp.width / 2,
  };
  tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
}

void _dashed(Canvas canvas, Offset a, Offset b, Paint paint) {
  const dash = 4.0, gap = 3.0;
  var x = a.dx;
  while (x < b.dx) {
    canvas.drawLine(Offset(x, a.dy), Offset((x + dash).clamp(a.dx, b.dx), a.dy), paint);
    x += dash + gap;
  }
}

/// 해역별 주간 막대그래프 (수온 또는 염도). 해역마다 주차 막대를 나란히
/// 그리고, 첫 주와 마지막 주 값만 숫자로 적는다.
class SeaBarChart extends StatelessWidget {
  const SeaBarChart({super.key, required this.groups, required this.top, required this.step, this.height = 200});

  /// 해역 이름 → (주차별 값, 해당 해역 양식장 수)
  final Map<String, (List<double>, int)> groups;
  final double top;
  final double step;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _SeaBarPainter(groups: groups, top: top, step: step)),
    );
  }
}

class _SeaBarPainter extends CustomPainter {
  _SeaBarPainter({required this.groups, required this.top, required this.step});

  final Map<String, (List<double>, int)> groups;
  final double top;
  final double step;

  @override
  void paint(Canvas canvas, Size size) {
    const l = 26.0, r = 4.0, t = 14.0, b = 36.0;
    final pw = size.width - l - r, ph = size.height - t - b;
    double y(double v) => t + ph - (v / top) * ph;
    final gridPaint = Paint()..color = _grid;

    for (var v = 0.0; v <= top + 1e-9; v += step) {
      canvas.drawLine(Offset(l, y(v)), Offset(size.width - r, y(v)), gridPaint);
      _text(canvas, v.toStringAsFixed(0), Offset(l - 5, y(v)), align: TextAlign.right, size: 9);
    }

    final areas = groups.keys.toList();
    final gw = pw / areas.length;
    for (var i = 0; i < areas.length; i++) {
      final (vals, farmCount) = groups[areas[i]]!;
      const gap = 2.0;
      final bw = ((gw - 14 - gap * (vals.length - 1)) / vals.length).clamp(3.0, 14.0);
      final gx = l + i * gw + (gw - (vals.length * bw + (vals.length - 1) * gap)) / 2;
      for (var k = 0; k < vals.length; k++) {
        final x = gx + k * (bw + gap), yy = y(vals[k]);
        canvas.drawRRect(
          RRect.fromRectAndCorners(Rect.fromLTRB(x, yy, x + bw, t + ph),
              topLeft: Radius.circular(bw / 4), topRight: Radius.circular(bw / 4)),
          Paint()..color = weekRamp[k % weekRamp.length],
        );
        final last = k == vals.length - 1;
        if (k == 0 || last) {
          _text(canvas, vals[k].toStringAsFixed(1), Offset(x + bw / 2 + (last ? 2 : -2), yy - 7),
              size: last ? 9 : 8,
              color: last ? AppColors.textPrimary : AppColors.textMuted,
              weight: last ? FontWeight.w700 : FontWeight.w400);
        }
      }
      final cx = l + i * gw + gw / 2;
      _text(canvas, areas[i], Offset(cx, size.height - 24), size: 11, color: AppColors.textSecondary, weight: FontWeight.w600);
      _text(canvas, '양식장 $farmCount곳', Offset(cx, size.height - 10), size: 9);
    }
    canvas.drawLine(Offset(l, t + ph), Offset(size.width - r, t + ph), Paint()..color = _axis);
  }

  @override
  bool shouldRepaint(covariant _SeaBarPainter old) => old.groups != groups || old.top != top;
}

/// DO·pH 추이 꺾은선. 기준 범위를 옅은 초록 띠와 점선으로 깔고, 기준
/// 밖 값은 빨간 점·굵은 숫자로 표시한다.
class ThresholdLineChart extends StatelessWidget {
  const ThresholdLineChart({
    super.key,
    required this.days,
    required this.values,
    required this.min,
    required this.max,
    required this.step,
    required this.isOk,
    this.lo,
    this.hi,
    this.height = 170,
  });

  final List<int> days;
  final List<double> values;
  final double min;
  final double max;
  final double step;
  final double? lo;
  final double? hi;
  final bool Function(double) isOk;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _ThresholdLinePainter(this)),
    );
  }
}

class _ThresholdLinePainter extends CustomPainter {
  _ThresholdLinePainter(this.c);

  final ThresholdLineChart c;

  @override
  void paint(Canvas canvas, Size size) {
    const l = 28.0, r = 8.0, t = 14.0, b = 24.0;
    final pw = size.width - l - r, ph = size.height - t - b;
    final n = c.days.length;
    double x(int i) => l + 12 + (n == 1 ? (pw - 24) / 2 : i * (pw - 24) / (n - 1));
    double y(double v) => t + ph - (v - c.min) / (c.max - c.min) * ph;

    final gridPaint = Paint()..color = _grid;
    for (var v = c.min; v <= c.max + 1e-9; v += c.step) {
      canvas.drawLine(Offset(l, y(v)), Offset(size.width - r, y(v)), gridPaint);
      final label = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
      _text(canvas, label, Offset(l - 5, y(v)), align: TextAlign.right, size: 9);
    }

    final bandTop = c.hi != null ? y(c.hi!) : t;
    final bandBottom = c.lo != null ? y(c.lo!) : t + ph;
    canvas.drawRect(Rect.fromLTRB(l, bandTop, size.width - r, bandBottom), Paint()..color = _ok.withValues(alpha: .07));
    final okPaint = Paint()
      ..color = _ok
      ..strokeWidth = 1;
    if (c.lo != null) {
      _dashed(canvas, Offset(l, y(c.lo!)), Offset(size.width - r, y(c.lo!)), okPaint);
      _text(canvas, '기준 ${_fmt(c.lo!)}${c.hi == null ? ' 이상' : ''}', Offset(l + 4, y(c.lo!) + 8),
          size: 9, color: _ok, align: TextAlign.left);
    }
    if (c.hi != null) {
      _dashed(canvas, Offset(l, y(c.hi!)), Offset(size.width - r, y(c.hi!)), okPaint);
      _text(canvas, '기준 ${_fmt(c.hi!)}', Offset(l + 4, y(c.hi!) - 7), size: 9, color: _ok, align: TextAlign.left);
    }

    final path = Path();
    for (var i = 0; i < n; i++) {
      final p = Offset(x(i), y(c.values[i]));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = _line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    for (var i = 0; i < n; i++) {
      final v = c.values[i], good = c.isOk(v), p = Offset(x(i), y(v));
      canvas.drawCircle(p, good ? 4.5 : 5.5, Paint()..color = Colors.white);
      canvas.drawCircle(p, good ? 3 : 4, Paint()..color = good ? _line : _crit);
      _text(canvas, v.toStringAsFixed(1), Offset(p.dx, p.dy - 10),
          size: 9, color: good ? AppColors.textPrimary : _crit, weight: good ? FontWeight.w400 : FontWeight.w700);
      _text(canvas, '${c.days[i]}', Offset(p.dx, size.height - 10), size: 9.5, color: AppColors.textSecondary);
    }
    canvas.drawLine(Offset(l, t + ph), Offset(size.width - r, t + ph), Paint()..color = _axis);
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  bool shouldRepaint(covariant _ThresholdLinePainter old) => old.c != c;
}
