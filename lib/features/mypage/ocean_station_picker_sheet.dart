import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/data_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/ocean_reading.dart';
import '../../data/services/ocean_station_preference_store.dart';

/// Opened from MyPage to let the user pick which real sea location (바다
/// 위치) drives the water-temp display. Only stations publishing a 중층 or
/// 저층 reading are offered — see [oceanStationsProvider].
Future<void> showOceanStationPickerSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => const _OceanStationPickerSheet(),
  );
}

class _OceanStationPickerSheet extends ConsumerWidget {
  const _OceanStationPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stationsAsync = ref.watch(oceanStationsProvider);
    final selectedAsync = ref.watch(selectedOceanStationProvider);
    final selectedCode = selectedAsync.valueOrNull?.code;

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
            const Text('수온을 받아올 관측소를 골라주세요 — 표층은 제외하고 중층·저층 수온만 제공됩니다.',
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
              child: stationsAsync.when(
                data: (stations) {
                  if (stations.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('선택 가능한 관측소가 없습니다.', style: TextStyle(color: AppColors.textMuted)),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: stations.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.divider),
                    itemBuilder: (context, i) {
                      final station = stations[i];
                      final selected = station.code == selectedCode;
                      return InkWell(
                        onTap: () async {
                          await ref.read(selectedOceanStationProvider.notifier).select(
                                OceanStationSelection(code: station.code, name: station.name),
                              );
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(station.name,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: selected ? AppColors.brand : AppColors.textPrimary,
                                    )),
                              ),
                              for (final layer in station.layers) ...[
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: AppColors.brandTint, borderRadius: BorderRadius.circular(20)),
                                  child: Text(oceanLayerDisplayLabel(layer) ?? layer,
                                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.brand)),
                                ),
                              ],
                              if (selected) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.check_circle, size: 16, color: AppColors.brand),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
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
}
