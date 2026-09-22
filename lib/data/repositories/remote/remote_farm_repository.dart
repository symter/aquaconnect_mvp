import '../../models/farm.dart';
import '../../services/api_client.dart';
import '../farm_repository.dart';

class RemoteFarmRepository implements FarmRepository {
  RemoteFarmRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  @override
  Future<List<Farm>> listFarms({String? orgId}) async {
    final json = await _api.get('/api/farms') as List<dynamic>;
    return json.map((e) => Farm.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<Farm?> getFarm(String farmId) async {
    try {
      final json = await _api.get('/api/farms/$farmId') as Map<String, dynamic>;
      return Farm.fromJson(json);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
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
    final json = await _api.post('/api/farms', body: {
      'name': name,
      'address': address,
      'ownerContact': ownerContact,
      'region': region,
      'nearestStationCode': nearestStationCode,
      'nearestStationName': nearestStationName,
    }) as Map<String, dynamic>;
    return Farm.fromJson(json);
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
    final json = await _api.put('/api/farms/$farmId', body: {
      'name': name,
      'address': address,
      'ownerContact': ownerContact,
      'region': region,
      'nearestStationCode': nearestStationCode,
      'nearestStationName': nearestStationName,
    }) as Map<String, dynamic>;
    return Farm.fromJson(json);
  }

  @override
  Future<void> deleteFarm(String farmId) async {
    await _api.delete('/api/farms/$farmId');
  }
}
