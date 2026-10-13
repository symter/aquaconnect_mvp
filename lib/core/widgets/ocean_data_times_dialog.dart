import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';
import '../../data/models/ocean_reading.dart';

/// Shows when each part of [snapshot] was measured: the realtime water
/// temperature and the (much less frequent) 어장환경 survey values.
Future<void> showOceanDataTimesDialog(BuildContext context, OceanSnapshot snapshot) {
  final format = DateFormat('yyyy.MM.dd HH:mm');
  final quality = snapshot.waterQuality;
  final layerLabel = oceanLayerDisplayLabel(snapshot.layer);

  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('최근 관측 시각', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Entry(
            title: '수온 · 실시간',
            time: snapshot.observedAt == null ? '정보 없음' : format.format(snapshot.observedAt!),
            detail: '${snapshot.stationName} 관측소${layerLabel == null ? '' : ' · $layerLabel'}',
          ),
          const SizedBox(height: 14),
          _Entry(
            title: '염도 · 용존산소 · 수질',
            time: quality == null ? '정보 없음' : format.format(quality.observedAt),
            detail: quality == null
                ? '가까운 어장환경 조사 정점이 없습니다'
                : '${quality.pointName} (관측소에서 ${quality.distanceKm.toStringAsFixed(1)}km) · 저층 기준',
          ),
          const SizedBox(height: 14),
          const Text(
            '수질 값은 국립수산과학원 어장환경 정기조사(연 4회 내외) 자료라 실시간 수온보다 관측 시각이 오래될 수 있어요.',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          if (snapshot.fetchedAt != null) ...[
            const SizedBox(height: 8),
            Text('마지막 조회 · ${DateFormat('HH:mm:ss').format(snapshot.fetchedAt!)}',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('닫기')),
      ],
    ),
  );
}

class _Entry extends StatelessWidget {
  const _Entry({required this.title, required this.time, required this.detail});

  final String title;
  final String time;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(time, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        Text(detail, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
      ],
    );
  }
}
