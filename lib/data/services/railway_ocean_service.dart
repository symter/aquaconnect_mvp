import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ocean_reading.dart';
import 'ocean_service.dart';

/// Talks to the `server/` API's `/api/ocean/*` routes, which wrap the NIFS
/// `risaList` OpenAPI so Flutter Web never hits it (and its CORS policy)
/// directly.
///
/// That upstream API only reports the current water temperature per
/// station — no salinity, dissolved oxygen, red tide status, or history —
/// so [fetchSnapshot] leaves those fields null/short rather than inventing
/// numbers. See `server/README.md` for the API contract.
class RailwayOceanService implements OceanService {
  RailwayOceanService({required String baseUrl, http.Client? client})
      : _baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  /// Preference order when a station reports more than one depth: farmed
  /// fish live at mid/bottom depth, not the surface, so 저층 (bottom) wins
  /// over 중층 (mid) wins over 표층 (surface) whenever more than one is
  /// available for the same station.
  static const _layerPriority = ['저층', '중층', '표층'];

  OceanObservation? _pickPreferred(List<OceanObservation> observations) {
    final withTemp = observations.where((o) => o.waterTempC != null).toList();
    for (final layer in _layerPriority) {
      for (final o in withTemp) {
        if (o.layer == layer) return o;
      }
    }
    return withTemp.isEmpty ? null : withTemp.first;
  }

  @override
  Future<List<OceanObservation>> fetchRealtime({String? station}) async {
    final uri = Uri.parse('$_baseUrl/api/ocean/realtime').replace(
      queryParameters: station == null ? null : {'station': station},
    );
    final response = await _client.get(uri, headers: const {'Accept': 'application/json'});
    if (response.statusCode != 200) {
      throw Exception('실시간 수온 조회 실패 (HTTP ${response.statusCode})');
    }
    final body = jsonDecode(response.body) as List<dynamic>;
    return body.map((e) => OceanObservation.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<OceanSnapshot> fetchSnapshot({
    required String stationCode,
    required String stationName,
    required String region,
  }) async {
    final observations = await fetchRealtime(station: stationCode);
    final picked = _pickPreferred(observations);

    if (picked == null) {
      throw Exception('$stationName 관측소의 수온 데이터를 찾을 수 없습니다.');
    }

    return OceanSnapshot(
      region: region,
      stationName: picked.stationName,
      waterTemp: picked.waterTempC!,
      layer: picked.layer,
      sevenDayTemps: [picked.waterTempC!],
      sevenDayLabels: const ['오늘'],
      source: 'NIFS RISA (실시간, 이력 데이터 미제공)',
      hasTrendHistory: false,
    );
  }

  @override
  Future<List<OceanStation>> fetchStations() async {
    final observations = await fetchRealtime();
    final byCode = <String, (String name, Set<String> layers)>{};
    for (final o in observations) {
      if (o.stationCode == '-' || (o.layer != '중층' && o.layer != '저층')) continue;
      final existing = byCode[o.stationCode];
      if (existing == null) {
        byCode[o.stationCode] = (o.stationName, {o.layer});
      } else {
        existing.$2.add(o.layer);
      }
    }
    final stations = byCode.entries
        .map((e) => OceanStation(code: e.key, name: e.value.$1, layers: e.value.$2.toList()))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return stations;
  }
}
