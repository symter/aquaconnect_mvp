import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ocean_reading.dart';
import 'ocean_service.dart';

/// Talks to the `server/` API's `/api/ocean/*` routes, which wrap the NIFS
/// `risaList` OpenAPI so Flutter Web never hits it (and its CORS policy)
/// directly.
///
/// `risaList` only reports the current water temperature per station, so
/// [fetchSnapshot] also asks `/api/ocean/quality` for the nearest NIFS
/// 어장환경 survey (salinity, DO, pH, nutrients, ...). Red tide status and
/// temperature history have no source and stay null/short rather than
/// inventing numbers. See `server/README.md` for the API contract.
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
    bool refresh = false,
  }) async {
    final qualityFuture = resolveWaterQuality(fetchWaterQuality(stationCode, refresh: refresh));
    final observations = await fetchRealtime(station: stationCode);
    final picked = _pickPreferred(observations);

    if (picked == null) {
      throw Exception('$stationName 관측소의 수온 데이터를 찾을 수 없습니다.');
    }

    final (quality, qualityStatus) = await qualityFuture;
    return OceanSnapshot(
      region: region,
      stationName: picked.stationName,
      waterTemp: picked.waterTempC!,
      layer: picked.layer,
      observedAt: parseObservationTime(picked.observedDate, picked.observedTime),
      salinity: quality?.value('salinity'),
      dissolvedOxygen: quality?.value('dissolvedOxygen'),
      waterQuality: quality,
      waterQualityStatus: qualityStatus,
      fetchedAt: DateTime.now(),
      source: quality == null ? 'NIFS RISA (실시간 수온)' : 'NIFS RISA (실시간 수온) · NIFS 어장환경관측 (수질)',
    );
  }

  @override
  Future<WaterQuality?> fetchWaterQuality(String stationCode, {bool refresh = false}) async {
    final info = oceanStationCatalog[stationCode];
    if (info == null) throw Exception('$stationCode 관측소의 좌표를 알 수 없습니다.');
    final uri = Uri.parse('$_baseUrl/api/ocean/quality').replace(queryParameters: {
      'lat': '${info.latitude}',
      'lon': '${info.longitude}',
      if (refresh) 'refresh': '1',
    });
    final response = await _client.get(uri, headers: const {'Accept': 'application/json'});
    if (response.statusCode != 200) {
      throw Exception('수질 조회 실패 (HTTP ${response.statusCode})');
    }
    final body = jsonDecode(response.body);
    return body is Map<String, dynamic> ? WaterQuality.fromJson(body) : null;
  }

  @override
  Future<List<OceanStation>> fetchStations() async {
    final observations = await fetchRealtime();
    final byCode = <String, (String name, Set<String> layers)>{};
    for (final o in observations) {
      if (o.stationCode == '-' || o.waterTempC == null) continue;
      byCode.putIfAbsent(o.stationCode, () => (o.stationName, <String>{})).$2.add(o.layer);
    }
    final stations = byCode.entries.map((e) {
      final layers = sortLayersTopDown(e.value.$2);
      final info = oceanStationCatalog[e.key];
      return info != null
          ? OceanStation.fromCatalog(info, layers: layers)
          : OceanStation(code: e.key, name: e.value.$1, layers: layers);
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return stations;
  }
}
