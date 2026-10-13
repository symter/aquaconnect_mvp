import 'ocean_station_catalog.dart';

export 'ocean_station_catalog.dart' show OceanStationInfo, oceanStationCatalog;

/// A single real-time observation, shaped after the NIFS `risaList`
/// response normalized by `ocean_service` (ported from `D:\202609\index.mjs`).
class OceanObservation {
  const OceanObservation({
    required this.stationCode,
    required this.stationName,
    required this.observedDate,
    required this.observedTime,
    required this.layer,
    required this.waterTempC,
    required this.status,
  });

  final String stationCode;
  final String stationName;
  final String observedDate;
  final String observedTime;
  final String layer;
  final double? waterTempC;
  final String status;

  factory OceanObservation.fromJson(Map<String, dynamic> json) => OceanObservation(
        stationCode: json['관측소코드']?.toString() ?? json['stationCode']?.toString() ?? '-',
        stationName: json['관측소명']?.toString() ?? json['stationName']?.toString() ?? '-',
        observedDate: json['관측일자']?.toString() ?? json['observedDate']?.toString() ?? '-',
        observedTime: json['관측시각']?.toString() ?? json['observedTime']?.toString() ?? '-',
        layer: json['측정층']?.toString() ?? json['layer']?.toString() ?? '-',
        waterTempC: _toDouble(json['수온_C'] ?? json['waterTempC']),
        status: json['상태']?.toString() ?? json['status']?.toString() ?? '-',
      );

  static double? _toDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

/// A selectable NIFS observation point (바다 위치) for the MyPage / Info
/// station picker. [layers] holds every depth this station publishes
/// ('표층'/'중층'/'저층'), surface-only stations included.
class OceanStation {
  const OceanStation({
    required this.code,
    required this.name,
    required this.layers,
    this.sea,
    this.latitude,
    this.longitude,
  });

  /// Builds a station from the recorded official catalog entry, keeping
  /// [layers] from the live feed when given (it reflects what's actually
  /// reporting right now).
  factory OceanStation.fromCatalog(OceanStationInfo info, {List<String>? layers}) => OceanStation(
        code: info.code,
        name: info.name,
        layers: layers ?? info.layers,
        sea: info.sea,
        latitude: info.latitude,
        longitude: info.longitude,
      );

  final String code;
  final String name;
  final List<String> layers;
  final String? sea;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;
}

/// Sorts layers top-down (표층 → 중층 → 저층) for display.
List<String> sortLayersTopDown(Iterable<String> layers) {
  const order = ['표층', '중층', '저층'];
  return layers.toList()..sort((a, b) => order.indexOf(a).compareTo(order.indexOf(b)));
}

/// Maps a raw NIFS layer code ('표층'/'중층'/'저층') to the label shown in
/// the UI next to a water-temp value, e.g. "중층수" / "저층수".
String? oceanLayerDisplayLabel(String? layer) {
  switch (layer) {
    case '중층':
      return '중층수';
    case '저층':
      return '저층수';
    case '표층':
      return '표층수';
    default:
      return null;
  }
}

/// One NIFS 어장환경 survey (`femoSeaList`, via `GET /api/ocean/quality`)
/// at the survey point nearest to a station. Unlike the realtime water
/// temperature this is a periodic field survey (roughly quarterly), so
/// [observedAt] can be months old — the UI always shows it.
class WaterQuality {
  const WaterQuality({
    required this.pointName,
    required this.distanceKm,
    required this.observedAt,
    required this.surface,
    required this.bottom,
    this.depthM,
    this.transparencyM,
  });

  /// e.g. "부산 연안 1정점".
  final String pointName;
  final double distanceKm;
  final DateTime observedAt;
  final double? depthM;
  final double? transparencyM;

  /// Keyed by the server's field names: salinity, ph, dissolvedOxygen,
  /// cod, ammonia, nitrate, nitrite, din, totalNitrogen, dip,
  /// totalPhosphorus, silicate, chlorophyll, suspendedSolids, temp.
  final Map<String, double?> surface;
  final Map<String, double?> bottom;

  /// Farmed fish live below the surface, so the bottom-layer value wins
  /// when the survey has one (same reasoning as the water-temp layer pick).
  double? value(String key) => bottom[key] ?? surface[key];

  factory WaterQuality.fromJson(Map<String, dynamic> json) {
    Map<String, double?> layer(Object? raw) => {
          for (final e in (raw as Map<String, dynamic>? ?? const {}).entries) e.key: OceanObservation._toDouble(e.value),
        };
    return WaterQuality(
      pointName: '${json['fishery']} ${json['kind']} ${json['point']}정점',
      distanceKm: OceanObservation._toDouble(json['distanceKm']) ?? 0,
      observedAt: DateTime.parse(json['observedAt'] as String).toLocal(),
      depthM: OceanObservation._toDouble(json['depthM']),
      transparencyM: OceanObservation._toDouble(json['transparencyM']),
      surface: layer(json['surface']),
      bottom: layer(json['bottom']),
    );
  }
}

/// Parses a `risaList` observation's date ('2026-10-12' or '20261012') and
/// time ('10:30:00' / '10:30') into a local DateTime, or null if malformed.
DateTime? parseObservationTime(String date, String time) {
  final d = date.replaceAll('-', '');
  if (d.length != 8) return null;
  final t = time.split(':');
  return DateTime.tryParse(
    '${d.substring(0, 4)}-${d.substring(4, 6)}-${d.substring(6, 8)} '
    '${t[0].padLeft(2, '0')}:${(t.length > 1 ? t[1] : '00').padLeft(2, '0')}:00',
  );
}

/// Whether [OceanSnapshot.salinity] / [OceanSnapshot.dissolvedOxygen]
/// could be filled from a nearby NIFS 어장환경 survey point.
enum WaterQualityStatus {
  available,

  /// The lookup worked but no survey point lies within 50km.
  noneNearby,

  /// The lookup failed or the station has no known coordinates.
  unavailable,
}

/// Aggregated environment snapshot used to render the stat grid shown on
/// Info / AllReport / ReportDetail.
///
/// Water temperature comes from the realtime NIFS `risaList` feed (current
/// value only — NIFS exposes no history); [salinity], [dissolvedOxygen] and
/// the rest of [waterQuality] come from the nearest NIFS 어장환경 survey
/// point, and stay null unless [waterQualityStatus] is available.
class OceanSnapshot {
  const OceanSnapshot({
    required this.region,
    required this.stationName,
    required this.waterTemp,
    required this.source,
    this.salinity,
    this.dissolvedOxygen,
    this.waterQualityStatus = WaterQualityStatus.unavailable,
    this.layer,
    this.observedAt,
    this.waterQuality,
    this.fetchedAt,
  });

  final String region;
  final String stationName;
  final double waterTemp;
  final double? salinity;
  final double? dissolvedOxygen;
  final WaterQualityStatus waterQualityStatus;
  final String source;

  /// Which depth [waterTemp] was measured at ('표층'/'중층'/'저층'), when
  /// known. Null only for aggregate/synthetic snapshots (e.g. the
  /// multi-farm average on AllReport) that don't correspond to one reading.
  final String? layer;

  /// When the station measured [waterTemp].
  final DateTime? observedAt;

  final WaterQuality? waterQuality;

  /// When the app fetched this snapshot.
  final DateTime? fetchedAt;
}
