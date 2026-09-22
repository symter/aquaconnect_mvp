import 'package:uuid/uuid.dart';

import '../../mock/mock_seed.dart';
import '../../models/farm.dart';
import '../../models/risk_level.dart';
import '../farm_repository.dart';

class MockFarmRepository implements FarmRepository {
  static const _uuid = Uuid();

  @override
  Future<List<Farm>> listFarms({String? orgId}) async {
    return MockSeed.farms.where((f) => orgId == null || f.orgId == orgId).toList();
  }

  @override
  Future<Farm?> getFarm(String farmId) async {
    for (final farm in MockSeed.farms) {
      if (farm.id == farmId) return farm;
    }
    return null;
  }

  @override
  Future<Farm> createFarm({
    required String name,
    required String address,
    required String ownerContact,
    required String region,
    required String nearestStationCode,
    required String nearestStationName,
  }) async {
    final farm = Farm(
      id: 'farm-${_uuid.v4()}',
      orgId: MockSeed.orgId,
      name: name,
      region: region,
      address: address,
      nearestStationCode: nearestStationCode,
      nearestStationName: nearestStationName,
      riskLevel: RiskLevel.good,
      headline: '',
      waterTemp: 0,
      lastVisitDays: 0,
      assignedMemberName: MockSeed.currentMember.name,
      ownerContact: ownerContact,
    );
    MockSeed.farms.add(farm);
    return farm;
  }

  @override
  Future<Farm> updateFarm(
    String farmId, {
    required String name,
    required String address,
    required String ownerContact,
    required String region,
    required String nearestStationCode,
    required String nearestStationName,
  }) async {
    final index = MockSeed.farms.indexWhere((f) => f.id == farmId);
    if (index == -1) throw Exception('양식장을 찾을 수 없습니다.');
    final updated = MockSeed.farms[index].copyWith(
      name: name,
      address: address,
      ownerContact: ownerContact,
      region: region,
      nearestStationCode: nearestStationCode,
      nearestStationName: nearestStationName,
    );
    MockSeed.farms[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteFarm(String farmId) async {
    MockSeed.farms.removeWhere((f) => f.id == farmId);
  }
}
