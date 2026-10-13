import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 7-day mortality bar chart, matching the bar-height design pattern
/// (later days rendered darker/taller when trending up).
class MortalityBarChart extends StatelessWidget {
  const MortalityBarChart({super.key, required this.values, this.height = 52});

  final List<double> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    final maxV = values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b);
    final safeMax = maxV <= 0 ? 1.0 : maxV;

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (i) {
          final ratio = values[i] / safeMax;
          final isLast = i == values.length - 1;
          final isNearLast = i == values.length - 2;
          final color = isLast
              ? AppColors.danger
              : isNearLast
                  ? const Color(0xFFF0BBA5)
                  : AppColors.brandTint;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i == values.length - 1 ? 0 : 8),
              height: (height * ratio).clamp(4, height),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
            ),
          );
        }),
      ),
    );
  }
}

class ChartDayLabels extends StatelessWidget {
  const ChartDayLabels({super.key, required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: labels
          .map((l) => Text(l, style: const TextStyle(fontSize: 10, color: AppColors.textFaint)))
          .toList(),
    );
  }
}
