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

/// Stations selectable as a "바다 위치" from MyPage / Info — only those
/// publishing a 중층 or 저층 reading.
final oceanStationsProvider = FutureProvider<List<OceanStation>>((ref) {
  return ref.watch(oceanServiceProvider).fetchStations();
});

/// The 표층(surface) water-temp reading for the MyPage-selected "바다
/// 위치" station, shown alongside the station name. Unlike
/// [oceanStationsProvider] (which excludes surface-only stations from the
/// *pickable* list), this fetches the surface layer specifically for
/// whichever station the user already chose. Null when no station is
/// selected yet, or the station has no surface reading.
final selectedStationSurfaceTempProvider = FutureProvider<OceanObservation?>((ref) async {
  final selection = await ref.watch(selectedOceanStationProvider.future);
  if (selection == null) return null;
  final observations = await ref.watch(oceanServiceProvider).fetchRealtime(station: selection.code);
  for (final o in observations) {
    if (o.layer == '표층' && o.waterTempC != null) return o;
  }
  return null;
});
