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

/// The 3-tile grid (수온·염도·용존산소) repeated on Info / AllReport /
/// ReportDetail.
/// Salinity and DO read "주변 없음" when no 어장환경 survey point lies
/// within 50km, and "정보 없음" when the lookup itself failed.
class OceanStatGrid extends StatelessWidget {
  const OceanStatGrid({super.key, required this.snapshot});

  final OceanSnapshot snapshot;

  String _qualityValue(double? value) {
    if (value != null) return value.toStringAsFixed(1);
    return snapshot.waterQualityStatus == WaterQualityStatus.noneNearby ? '주변 없음' : '정보 없음';
  }

  @override
  Widget build(BuildContext context) {
    final layerLabel = oceanLayerDisplayLabel(snapshot.layer);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
              child: StatGridTile(label: '염도', value: _qualityValue(snapshot.salinity)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatGridTile(
                label: '용존산소',
                value: _qualityValue(snapshot.dissolvedOxygen),
                // 5 mg/L: the DO floor the farm report also uses.
                valueColor: switch (snapshot.dissolvedOxygen) {
                  null => null,
                  final v when v < 5 => AppColors.danger,
                  _ => AppColors.good,
                },
              ),
            ),
          ],
        ),
        if (snapshot.waterQualityStatus == WaterQualityStatus.noneNearby) ...[
          const SizedBox(height: 6),
          const Text('반경 50km 안에 어장환경 조사 정점이 없어 염도·용존산소를 표시할 수 없어요',
              style: TextStyle(fontSize: 9.5, color: AppColors.textMuted)),
        ],
      ],
    );
  }
}

/// The extra 어장환경 survey values (pH, nutrients, ...) beyond the 4-tile
/// [OceanStatGrid], laid out as two rows of four.
class WaterQualityGrid extends StatelessWidget {
  const WaterQualityGrid({super.key, required this.quality});

  final WaterQuality quality;

  static String _format(double? v) {
    if (v == null) return '-';
    if (v.abs() < 0.1) return v.toStringAsFixed(3);
    if (v.abs() < 10) return v.toStringAsFixed(2);
    return v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final tiles = [
      ('pH', _format(quality.value('ph'))),
      ('COD', _format(quality.value('cod'))),
      ('암모니아질소', _format(quality.value('ammonia'))),
      ('용존무기질소', _format(quality.value('din'))),
      ('용존무기인', _format(quality.value('dip'))),
      ('클로로필a', _format(quality.value('chlorophyll'))),
      ('부유물질', _format(quality.value('suspendedSolids'))),
      ('투명도', quality.transparencyM == null ? '-' : '${_format(quality.transparencyM)}m'),
    ];
    Widget row(int start) => Row(
          children: [
            for (var i = start; i < start + 4; i++) ...[
              if (i > start) const SizedBox(width: 8),
              Expanded(child: StatGridTile(label: tiles[i].$1, value: tiles[i].$2)),
            ],
          ],
        );
    return Column(
      children: [
        row(0),
        const SizedBox(height: 8),
        row(4),
      ],
    );
  }
}
