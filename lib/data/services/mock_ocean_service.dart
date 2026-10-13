import '../models/ocean_reading.dart';
import 'ocean_service.dart';

/// Canned data for mock mode. The farm-linked '001'/'002' codes keep the
/// numbers baked into the approved `.dc.html` designs; every real NIFS
/// station in [oceanStationCatalog] gets deterministic per-layer readings
/// so the 바다 위치 picker, GPS recommendation and Info screen behave like
/// the live feed (surface-only stations included).
class MockOceanService implements OceanService {
  static final Map<String, List<double>> _tempSeries = {
    '001': const [26.6, 26.9, 27.1, 27.4, 27.6, 27.7, 27.8],
    '002': const [26.9, 27.2, 27.6, 28.0, 28.3, 28.5, 28.6],
  };

  static const _salinity = {'001': 32.1, '002': 31.8};
  static const _dissolvedOxygen = {'001': 5.2, '002': 5.0};

  /// The farm-linked '001'/'002' codes predate real station data and only
  /// exist in this mock world, so their displayed layer is fixed rather
  /// than derived — 저층 (bottom), the more relevant depth for farmed fish.
  static const _legacyLayer = '저층';

  /// Hand-picked mid/bottom values kept from earlier mock data so those
  /// stations' numbers don't shift; everything else is derived by
  /// [_layerTemps].
  static const _fixedMidBottom = <String, (double mid, double? bottom)>{
    'bgj8a': (25.0, 24.3),
    'bgna3': (23.0, 14.2),
    'byd8a': (22.7, 19.5),
    'fggo3': (25.6, 24.8),
    'fth59': (26.4, 25.1),
    'fnm5b': (26.9, null),
    'fwbf1': (27.5, null),
  };

  static const _seaBase = {'동해': 22.5, '남해': 25.0, '서해': 23.0};

  /// Surface water runs a little warmer than mid depth, bottom cooler.
  static const _surfaceOffset = 0.4;
  static const _bottomOffset = -0.8;

  static Map<String, double> _layerTemps(OceanStationInfo info) {
    final fixed = _fixedMidBottom[info.code];
    final spread = info.code.codeUnits.fold<int>(0, (a, b) => a + b) % 12 / 10;
    final mid = fixed?.$1 ?? (_seaBase[info.sea] ?? 24.0) + spread;
    final bottom = fixed != null ? fixed.$2 : mid + _bottomOffset;
    return {
      for (final layer in info.layers)
        if (layer == '표층')
          layer: double.parse((mid + _surfaceOffset).toStringAsFixed(1))
        else if (layer == '중층')
          layer: mid
        else if (layer == '저층' && bottom != null)
          layer: double.parse(bottom.toStringAsFixed(1)),
    };
  }

  static List<OceanObservation> _catalogObservations(OceanStationInfo info) {
    return _layerTemps(info)
        .entries
        .map((e) => OceanObservation(
              stationCode: info.code,
              stationName: info.name,
              observedDate: _today(),
              observedTime: '12:00',
              layer: e.key,
              waterTempC: e.value,
              status: '정상',
            ))
        .toList();
  }

  @override
  Future<OceanSnapshot> fetchSnapshot({
    required String stationCode,
    required String stationName,
    required String region,
    bool refresh = false,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final info = oceanStationCatalog[stationCode];
    if (info != null) {
      final temps = _layerTemps(info);
      final layer = ['저층', '중층', '표층'].firstWhere(temps.containsKey);
      final temp = temps[layer]!;
      final (quality, qualityStatus) = await resolveWaterQuality(fetchWaterQuality(stationCode));
      return OceanSnapshot(
        region: region,
        stationName: info.name,
        waterTemp: temp,
        layer: layer,
        observedAt: _todayNoon(),
        salinity: quality?.value('salinity'),
        dissolvedOxygen: quality?.value('dissolvedOxygen'),
        waterQuality: quality,
        waterQualityStatus: qualityStatus,
        fetchedAt: DateTime.now(),
        source: 'NIFS RISA (실시간 수온) · NIFS 어장환경관측 (수질, mock)',
      );
    }

    final series = _tempSeries[stationCode] ?? _tempSeries['001']!;
    return OceanSnapshot(
      region: region,
      stationName: stationName,
      waterTemp: series.last,
      layer: _legacyLayer,
      salinity: _salinity[stationCode] ?? _salinity['001'],
      dissolvedOxygen: _dissolvedOxygen[stationCode] ?? _dissolvedOxygen['001'],
      waterQualityStatus: WaterQualityStatus.available,
      observedAt: _todayNoon(),
      fetchedAt: DateTime.now(),
      source: '바다누리 해양정보 · NIFS RISA (mock)',
    );
  }

  /// Like the live feed, stations with no survey point within 50km (here:
  /// 백령도) report none nearby.
  static const _noNearbySurvey = {'fbn69'};

  @override
  Future<WaterQuality?> fetchWaterQuality(String stationCode, {bool refresh = false}) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final info = oceanStationCatalog[stationCode];
    if (info == null) throw Exception('$stationCode 관측소의 좌표를 알 수 없습니다.');
    return _noNearbySurvey.contains(stationCode) ? null : _mockQuality(info);
  }

  @override
  Future<List<OceanObservation>> fetchRealtime({String? station}) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (station == null) {
      return [for (final info in oceanStationCatalog.values) ..._catalogObservations(info)];
    }
    final info = oceanStationCatalog[station];
    if (info != null) return _catalogObservations(info);

    final bottomTemp = (_tempSeries[station] ?? _tempSeries['001']!).last;
    final name = station == '002' ? '해남' : '완도';
    return [
      OceanObservation(
        stationCode: station,
        stationName: name,
        observedDate: _today(),
        observedTime: '12:00',
        layer: '표층',
        waterTempC: bottomTemp + _surfaceOffset,
        status: '정상',
      ),
      OceanObservation(
        stationCode: station,
        stationName: name,
        observedDate: _today(),
        observedTime: '12:00',
        layer: _legacyLayer,
        waterTempC: bottomTemp,
        status: '정상',
      ),
    ];
  }

  @override
  Future<List<OceanStation>> fetchStations() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return oceanStationCatalog.values
        .map((info) => OceanStation.fromCatalog(info, layers: sortLayersTopDown(_layerTemps(info).keys)))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Plausible 어장환경 survey values, shaped like a real `femoSeaList`
  /// record (a late-October survey) and nudged per station so switching
  /// stations visibly changes them.
  static WaterQuality _mockQuality(OceanStationInfo info) {
    final k = info.code.codeUnits.fold<int>(0, (a, b) => a + b) % 10 / 10;
    double r(double v, [int digits = 2]) => double.parse(v.toStringAsFixed(digits));
    return WaterQuality(
      pointName: '${info.name} 연안 1정점',
      distanceKm: r(1.5 + k * 8, 1),
      observedAt: DateTime(DateTime.now().year - 1, 10, 27, 15, 20),
      depthM: 30,
      transparencyM: r(3 + k * 3, 1),
      surface: {
        'salinity': r(32.4 + k), 'ph': r(8.04 + k / 10), 'dissolvedOxygen': r(6.7 + k),
        'cod': r(1.1 + k / 2), 'ammonia': r(0.008 + k / 100, 3), 'din': r(0.086 + k / 20, 3),
        'dip': r(0.011 + k / 100, 3), 'chlorophyll': r(0.42 + k), 'suspendedSolids': r(4.2 + k * 3),
      },
      bottom: {
        'salinity': r(33.0 + k), 'ph': r(7.99 + k / 10), 'dissolvedOxygen': r(6.2 + k),
        'cod': r(0.88 + k / 2), 'ammonia': r(0.006 + k / 100, 3), 'din': r(0.125 + k / 20, 3),
        'dip': r(0.02 + k / 100, 3), 'chlorophyll': r(0.12 + k), 'suspendedSolids': r(9.7 + k * 3),
      },
    );
  }

  static DateTime _todayNoon() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 12);
  }

  static String _today() {
    final d = DateTime.now();
    return '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
  }
}
