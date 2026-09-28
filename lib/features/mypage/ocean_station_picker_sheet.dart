import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/data_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/ocean_reading.dart';
import '../../data/services/location_service.dart';
import '../../data/services/ocean_station_preference_store.dart';

/// Opened from MyPage to let the user pick which real sea location (바다
/// 위치) drives the water-temp display. Every NIFS station is offered,
/// surface-only ones included, and "내 위치에서 찾기" uses the browser's
/// GPS to sort stations by distance and recommend the nearest one.
Future<void> showOceanStationPickerSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => const _OceanStationPickerSheet(),
  );
}

class _OceanStationPickerSheet extends ConsumerStatefulWidget {
  const _OceanStationPickerSheet();

  @override
  ConsumerState<_OceanStationPickerSheet> createState() => _OceanStationPickerSheetState();
}

class _OceanStationPickerSheetState extends ConsumerState<_OceanStationPickerSheet> {
  GeoPoint? _position;
  bool _locating = false;
  String? _locationError;

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      final position = await ref.read(locationServiceProvider).currentPosition();
      if (mounted) setState(() => _position = position);
    } catch (e) {
      if (mounted) setState(() => _locationError = e.toString());
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _select(OceanStation station) async {
    await ref.read(selectedOceanStationProvider.notifier).select(
          OceanStationSelection(code: station.code, name: station.name),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final stationsAsync = ref.watch(oceanStationsProvider);
    final selectedCode = ref.watch(selectedOceanStationProvider).valueOrNull?.code;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const Text('바다 위치 선택', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.brandDark)),
            const SizedBox(height: 4),
            const Text('수온을 받아올 관측소를 골라주세요 — 표층·중층·저층 수온을 모두 제공합니다.',
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _locating ? null : _locate,
                icon: _locating
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location, size: 16),
                label: Text(_locating ? '현재 위치 확인 중…' : (_position == null ? '내 위치에서 가까운 관측소 찾기' : '내 위치 다시 확인')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brand,
                  side: const BorderSide(color: AppColors.brandTintBorder),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            if (_locationError != null) ...[
              const SizedBox(height: 6),
              Text(_locationError!, style: const TextStyle(fontSize: 11.5, color: AppColors.danger)),
            ],
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
              child: stationsAsync.when(
                data: (stations) => _buildList(stations, selectedCode),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('관측소 목록을 불러오지 못했습니다.\n$e', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<OceanStation> stations, String? selectedCode) {
    if (stations.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text('선택 가능한 관측소가 없습니다.', style: TextStyle(color: AppColors.textMuted)),
      );
    }

    final position = _position;
    final distances = <String, double>{};
    var ordered = stations;
    StationDistance? nearest;
    if (position != null) {
      final sorted = sortByDistance(position, stations);
      for (final s in sorted) {
        distances[s.station.code] = s.distanceKm;
      }
      nearest = sorted.isEmpty ? null : sorted.first;
      // Stations without recorded coordinates (none today) sink to the end.
      ordered = [...sorted.map((s) => s.station), ...stations.where((s) => !s.hasCoordinates)];
    }

    return ListView(
      shrinkWrap: true,
      children: [
        if (nearest != null) ...[
          _RecommendationCard(
            nearest: nearest,
            isSelected: nearest.station.code == selectedCode,
            onSelect: () => _select(nearest!.station),
          ),
          const SizedBox(height: 8),
        ],
        for (var i = 0; i < ordered.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: AppColors.divider),
          _StationRow(
            station: ordered[i],
            distanceKm: distances[ordered[i].code],
            selected: ordered[i].code == selectedCode,
            onTap: () => _select(ordered[i]),
          ),
        ],
      ],
    );
  }
}

String _formatDistance(double km) => km < 10 ? '${km.toStringAsFixed(1)}km' : '${km.round()}km';

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.nearest, required this.isSelected, required this.onSelect});

  final StationDistance nearest;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final station = nearest.station;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.brandTint,
        border: Border.all(color: AppColors.brandTintBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.near_me, size: 18, color: AppColors.brand),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('추천 · 내 위치에서 가장 가까운 관측소',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.brand)),
                const SizedBox(height: 2),
                Text('${station.name} · ${_formatDistance(nearest.distanceKm)}',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.brandDark)),
              ],
            ),
          ),
          TextButton(
            onPressed: isSelected ? null : onSelect,
            child: Text(isSelected ? '선택됨' : '이 관측소로 설정',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _StationRow extends StatelessWidget {
  const _StationRow({required this.station, required this.distanceKm, required this.selected, required this.onTap});

  final OceanStation station;
  final double? distanceKm;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (station.sea != null) station.sea!,
      if (distanceKm != null) _formatDistance(distanceKm!),
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(station.name,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: selected ? AppColors.brand : AppColors.textPrimary,
                      )),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(meta, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                  ],
                ],
              ),
            ),
            for (final layer in station.layers)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.brandTint, borderRadius: BorderRadius.circular(20)),
                child: Text(oceanLayerDisplayLabel(layer) ?? layer,
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.brand)),
              ),
            if (selected) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check_circle, size: 16, color: AppColors.brand),
            ],
          ],
        ),
      ),
    );
  }
}
