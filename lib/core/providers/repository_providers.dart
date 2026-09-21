import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/disease_info_repository.dart';
import '../../data/repositories/farm_repository.dart';
import '../../data/repositories/memo_repository.dart';
import '../../data/repositories/mock/mock_auth_repository.dart';
import '../../data/repositories/mock/mock_disease_info_repository.dart';
import '../../data/repositories/mock/mock_farm_repository.dart';
import '../../data/repositories/mock/mock_memo_repository.dart';
import '../../data/repositories/mock/mock_report_repository.dart';
import '../../data/repositories/mock/mock_share_link_repository.dart';
import '../../data/repositories/remote/remote_auth_repository.dart';
import '../../data/repositories/remote/remote_disease_info_repository.dart';
import '../../data/repositories/remote/remote_farm_repository.dart';
import '../../data/repositories/remote/remote_memo_repository.dart';
import '../../data/repositories/remote/remote_report_repository.dart';
import '../../data/repositories/remote/remote_share_link_repository.dart';
import '../../data/repositories/report_repository.dart';
import '../../data/repositories/share_link_repository.dart';
import '../../data/services/api_client.dart';
import '../../data/services/auth_token_store.dart';
import '../../data/services/mock_ocean_service.dart';
import '../../data/services/ocean_service.dart';
import '../../data/services/ocean_station_preference_store.dart';
import '../../data/services/railway_ocean_service.dart';
import '../config/env.dart';

// `Env.useMock` (default true) picks between the in-memory mock_*
// repositories — fully clickable with zero backend — and the remote_*
// ones backed by the `server/` API. Both implement the same interfaces
// (lib/data/repositories/*.dart) so nothing above this layer cares which
// is active.

final authTokenStoreProvider = Provider<AuthTokenStore>((ref) => AuthTokenStore());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(tokenStore: ref.watch(authTokenStoreProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (Env.useMock) return MockAuthRepository();
  return RemoteAuthRepository(apiClient: ref.watch(apiClientProvider), tokenStore: ref.watch(authTokenStoreProvider));
});

final farmRepositoryProvider = Provider<FarmRepository>((ref) {
  if (Env.useMock) return MockFarmRepository();
  return RemoteFarmRepository(apiClient: ref.watch(apiClientProvider));
});

final memoRepositoryProvider = Provider<MemoRepository>((ref) {
  if (Env.useMock) return MockMemoRepository();
  return RemoteMemoRepository(apiClient: ref.watch(apiClientProvider));
});

final diseaseInfoRepositoryProvider = Provider<DiseaseInfoRepository>((ref) {
  if (Env.useMock) return MockDiseaseInfoRepository();
  return RemoteDiseaseInfoRepository(apiClient: ref.watch(apiClientProvider));
});

final oceanServiceProvider = Provider<OceanService>((ref) {
  if (Env.useMock) return MockOceanService();
  return RailwayOceanService(baseUrl: Env.apiBaseUrl);
});

final oceanStationPreferenceStoreProvider = Provider<OceanStationPreferenceStore>((ref) {
  return OceanStationPreferenceStore();
});

/// The MyPage-selected "바다 위치" (sea location), loaded from local storage
/// on first watch. Null means the user hasn't picked one yet.
final selectedOceanStationProvider =
    AsyncNotifierProvider<SelectedOceanStationNotifier, OceanStationSelection?>(SelectedOceanStationNotifier.new);

class SelectedOceanStationNotifier extends AsyncNotifier<OceanStationSelection?> {
  @override
  Future<OceanStationSelection?> build() {
    return ref.watch(oceanStationPreferenceStoreProvider).read();
  }

  Future<void> select(OceanStationSelection selection) async {
    await ref.read(oceanStationPreferenceStoreProvider).write(selection);
    state = AsyncValue.data(selection);
  }
}

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  if (Env.useMock) {
    return MockReportRepository(
      farmRepository: ref.watch(farmRepositoryProvider),
      memoRepository: ref.watch(memoRepositoryProvider),
      oceanService: ref.watch(oceanServiceProvider),
    );
  }
  return RemoteReportRepository(apiClient: ref.watch(apiClientProvider));
});

final shareLinkRepositoryProvider = Provider<ShareLinkRepository>((ref) {
  if (Env.useMock) {
    return MockShareLinkRepository(
      farmRepository: ref.watch(farmRepositoryProvider),
      reportRepository: ref.watch(reportRepositoryProvider),
    );
  }
  return RemoteShareLinkRepository(apiClient: ref.watch(apiClientProvider));
});

final authStateProvider = StreamProvider<AuthSession?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges();
});
