import '../models/farm.dart';

abstract class FarmRepository {
  Future<List<Farm>> listFarms({String? orgId});

  Future<Farm?> getFarm(String farmId);

  /// Registers a new farm. [name], [address] and [ownerContact] are
  /// enforced as required at the form layer (양식장명 / 위치 / 전화번호),
  /// even though [address] is the only one the DB schema itself requires.
  Future<Farm> createFarm({
    required String name,
    required String address,
    required String ownerContact,
    required String region,
    required String nearestStationCode,
    required String nearestStationName,
  });

  Future<Farm> updateFarm(
    String farmId, {
    required String name,
    required String address,
    required String ownerContact,
    required String region,
    required String nearestStationCode,
    required String nearestStationName,
  });

  Future<void> deleteFarm(String farmId);
}
