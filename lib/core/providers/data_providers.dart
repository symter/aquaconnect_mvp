import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/disease_info.dart';
import '../../data/models/farm.dart';
import '../../data/models/memo.dart';
import '../../data/models/ocean_reading.dart';
import '../../data/models/org_member.dart';
import '../../data/models/report.dart';
import '../../data/models/share_link.dart';
import '../../data/services/ocean_service.dart';
import 'repository_providers.dart';

/// Org roster, used by the memo composer's '/' assignee menu.
final orgMembersProvider = FutureProvider<List<OrgMember>>((ref) {
  return ref.watch(orgRepositoryProvider).listMembers();
});

final farmsProvider = FutureProvider<List<Farm>>((ref) {
  return ref.watch(farmRepositoryProvider).listFarms();
});

final farmByIdProvider = FutureProvider.family<Farm?, String>((ref, farmId) {
  return ref.watch(farmRepositoryProvider).getFarm(farmId);
});

final memosProvider = StreamProvider.family<List<Memo>, String?>((ref, farmId) {
  return ref.watch(memoRepositoryProvider).watchMemos(farmId: farmId);
});

/// The signed-in member's 오늘의 업무: open memos that are theirs
/// ([Memo.isOpenTaskFor]) plus how many they finished today. Drives the Home
/// card and the 메모 tab badge; null until memos and the session load.
final myTodayTasksProvider = Provider<({List<Memo> open, int doneToday})?>((ref) {
  final memos = ref.watch(memosProvider(null)).valueOrNull;
  final me = ref.watch(authStateProvider).valueOrNull?.member;
  if (memos == null || me == null) return null;
  final now = DateTime.now();
  bool today(DateTime at) {
    final l = at.toLocal();
    return l.year == now.year && l.month == now.month && l.day == now.day;
  }

  return (
    open: memos.where((m) => m.isOpenTaskFor(memberId: me.id, memberName: me.name)).toList(),
    doneToday: memos.where((m) => m.isDone && m.doneByMemberId == me.id && today(m.doneAt!)).length,
  );
});

/// Bytes for one memo photo. Kept (not autoDispose) so scrolling back to a
/// memo doesn't re-download its thumbnails.
final memoPhotoProvider = FutureProvider.family<Uint8List, String>((ref, photoId) {
  return ref.watch(memoRepositoryProvider).loadPhoto(photoId);
});

/// Bytes of a 댓글 첨부 photo (cached per attachment).
final commentAttachmentProvider = FutureProvider.family<Uint8List, String>((ref, attachmentId) {
  return ref.watch(memoRepositoryProvider).loadCommentAttachment(attachmentId);
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

/// Every share link issued by the org (active or not), newest first.
final shareLinksProvider = FutureProvider<List<ShareLink>>((ref) {
  return ref.watch(shareLinkRepositoryProvider).listShareLinks();
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

/// 염도·용존산소 averaged over the nearest 어장환경 survey of every station
/// the org's farms are linked to, for the AllReport stat grid. The status is
/// noneNearby only when every station lacks a survey point within 50km.
final fleetWaterQualityProvider =
    FutureProvider<({double? salinity, double? dissolvedOxygen, WaterQualityStatus status})>((ref) async {
  final farms = await ref.watch(farmsProvider.future);
  final service = ref.watch(oceanServiceProvider);
  final codes = {for (final f in farms) if (f.nearestStationCode.isNotEmpty) f.nearestStationCode};
  final results = await Future.wait(codes.map((code) => resolveWaterQuality(service.fetchWaterQuality(code))));

  double? average(String key) {
    final values = [for (final (q, _) in results) ?q?.value(key)];
    return values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length;
  }

  final status = results.any((r) => r.$2 == WaterQualityStatus.available)
      ? WaterQualityStatus.available
      : results.isNotEmpty && results.every((r) => r.$2 == WaterQualityStatus.noneNearby)
          ? WaterQualityStatus.noneNearby
          : WaterQualityStatus.unavailable;
  return (salinity: average('salinity'), dissolvedOxygen: average('dissolvedOxygen'), status: status);
});
