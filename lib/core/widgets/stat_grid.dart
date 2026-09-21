import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../../data/models/ocean_reading.dart';

class StatGridTile extends StatelessWidget {
  const StatGridTile({super.key, required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
      decoration: BoxDecoration(color: AppColors.neutralCard, borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 9.5, color: AppColors.textTertiary)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: valueColor ?? AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// The 4-tile grid (수온·염도·적조·용존산소) repeated on Info / AllReport /
/// ReportDetail / SharedReportWeb.
class OceanStatGrid extends StatelessWidget {
  const OceanStatGrid({super.key, required this.snapshot});

  final OceanSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final layerLabel = oceanLayerDisplayLabel(snapshot.layer);
    return Row(
      children: [
        Expanded(
          child: StatGridTile(
            label: layerLabel == null ? '수온' : '수온 · $layerLabel',
            value: '${snapshot.waterTemp.toStringAsFixed(1)}℃',
            valueColor: AppColors.danger,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StatGridTile(
            label: '염도',
            value: snapshot.salinity == null ? '정보 없음' : snapshot.salinity!.toStringAsFixed(1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StatGridTile(
            label: '적조',
            value: snapshot.redTideStatus ?? '정보 없음',
            valueColor: AppColors.good,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StatGridTile(
            label: '용존산소',
            value: snapshot.dissolvedOxygen?.toStringAsFixed(1) ?? '정보 없음',
            valueColor: AppColors.good,
          ),
        ),
      ],
    );
  }
}
