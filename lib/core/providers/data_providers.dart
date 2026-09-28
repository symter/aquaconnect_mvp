import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/disease_info.dart';
import '../../data/models/farm.dart';
import '../../data/models/memo.dart';
import '../../data/models/ocean_reading.dart';
import '../../data/models/report.dart';
import 'repository_providers.dart';

final farmsProvider = FutureProvider<List<Farm>>((ref) {
  return ref.watch(farmRepositoryProvider).listFarms();
});

final farmByIdProvider = FutureProvider.family<Farm?, String>((ref, farmId) {
  return ref.watch(farmRepositoryProvider).getFarm(farmId);
});

final memosProvider = StreamProvider.family<List<Memo>, String?>((ref, farmId) {
  return ref.watch(memoRepositoryProvider).watchMemos(farmId: farmId);
});

final diseaseInfoProvider = FutureProvider<List<DiseaseInfo>>((ref) {
  return ref.watch(diseaseInfoRepositoryProvider).listDiseaseInfo();
});

final reportProvider = FutureProvider.family<Report?, String>((ref, farmId) {
  return ref.watch(reportRepositoryProvider).getLatestReport(farmId);
});

final allReportsProvider = FutureProvider<List<Report>>((ref) async {
  final farms = await ref.watch(farmsProvider.future);
  return ref.watch(reportRepositoryProvider).listLatestReports(farmIds: farms.map((f) => f.id).toList());
});

/// Every station selectable as a "바다 위치" from MyPage / Info, surface-only
/// ('표층') stations included, with official coordinates where recorded.
final oceanStationsProvider = FutureProvider<List<OceanStation>>((ref) {
  return ref.watch(oceanServiceProvider).fetchStations();
});

/// All current readings (표층 → 중층 → 저층) for the MyPage-selected "바다
/// 위치" station. Empty when no station is selected yet.
final selectedStationReadingsProvider = FutureProvider<List<OceanObservation>>((ref) async {
  final selection = await ref.watch(selectedOceanStationProvider.future);
  if (selection == null) return const [];
  final observations = await ref.watch(oceanServiceProvider).fetchRealtime(station: selection.code);
  final withTemp = observations.where((o) => o.waterTempC != null && o.stationCode == selection.code);
  final order = sortLayersTopDown(withTemp.map((o) => o.layer).toSet());
  return [for (final layer in order) withTemp.firstWhere((o) => o.layer == layer)];
});
