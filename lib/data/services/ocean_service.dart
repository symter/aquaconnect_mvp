import '../models/ocean_reading.dart';

/// Fetches ocean environment data. Real-time values are proxied through the
/// `ocean_service` Node app (deployed on Railway) so the Flutter Web build
/// never calls the NIFS API directly and hits its CORS restrictions.
///
/// [fetchSnapshot]'s `refresh` asks the server to bypass its cache of the
/// (slow-changing) 어장환경 survey data as well.
abstract class OceanService {
  Future<OceanSnapshot> fetchSnapshot({
    required String stationCode,
    required String stationName,
    required String region,
    bool refresh = false,
  });

  Future<List<OceanObservation>> fetchRealtime({String? station});

  /// Latest 어장환경 survey at the point nearest to [stationCode]'s
  /// coordinates. Null when no survey point lies within 50km; throws when
  /// the lookup fails or the station's coordinates are unknown.
  Future<WaterQuality?> fetchWaterQuality(String stationCode, {bool refresh = false});

  /// Lists the stations selectable as a "바다 위치" in MyPage — only those
  /// publishing a 중층 or 저층 reading (surface-only stations are excluded
  /// since farmed fish live below the surface, not at it).
  Future<List<OceanStation>> fetchStations();
}

/// Runs a [OceanService.fetchWaterQuality] call and maps its outcome onto
/// the snapshot fields. Water quality is supplementary, so a failure never
/// fails the whole snapshot.
Future<(WaterQuality?, WaterQualityStatus)> resolveWaterQuality(Future<WaterQuality?> lookup) async {
  try {
    final quality = await lookup;
    return (quality, quality == null ? WaterQualityStatus.noneNearby : WaterQualityStatus.available);
  } catch (_) {
    return (null, WaterQualityStatus.unavailable);
  }
}
