import '../models/ocean_reading.dart';
import 'ocean_service.dart';

/// Canned data matching the numbers baked into the approved `.dc.html`
/// designs, keyed by NIFS station code (001 = 완도, 002 = 해남).
class MockOceanService implements OceanService {
  static final Map<String, List<double>> _tempSeries = {
    '001': const [26.6, 26.9, 27.1, 27.4, 27.6, 27.7, 27.8],
    '002': const [26.9, 27.2, 27.6, 28.0, 28.3, 28.5, 28.6],
  };

  static const _salinity = {'001': 32.1, '002': 31.8};
  static const _dissolvedOxygen = {'001': 5.2, '002': 5.0};

  /// The farm-linked '001'/'002' codes above predate real station data and
  /// only ever existed inside this mock world, so their displayed layer is
  /// fixed rather than derived — pick 저층 (bottom) since that's the more
  /// relevant depth for farmed fish.
  static const _legacyLayer = '저층';

  /// Curated stand-ins for real NIFS station names/codes (see
  /// `D:\202609\index.mjs`), so the MyPage/Info "바다 위치 선택" picker has
  /// real-looking choices beyond the two farm-linked stations even without
  /// a live backend. `bottom == null` means that station only publishes a
  /// 중층 reading (mirrors real stations like 완도 백도/남해 미조).
  static const _extraStations = <String, _MockStationLayers>{
    'bgj8a': _MockStationLayers(name: '기장', mid: 25.0, bottom: 24.3),
    'bgna3': _MockStationLayers(name: '강릉', mid: 23.0, bottom: 14.2),
    'byd8a': _MockStationLayers(name: '영덕', mid: 22.7, bottom: 19.5),
    'fggo3': _MockStationLayers(name: '고성 가진', mid: 25.6, bottom: 24.8),
    'fth59': _MockStationLayers(name: '통영 학림', mid: 26.4, bottom: 25.1),
    'fnm5b': _MockStationLayers(name: '남해 미조', mid: 26.9),
    'fwbf1': _MockStationLayers(name: '완도 백도', mid: 27.5),
  };

  @override
  Future<OceanSnapshot> fetchSnapshot({
    required String stationCode,
    required String stationName,
    required String region,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final extra = _extraStations[stationCode];
    if (extra != null) {
      final usesBottom = extra.bottom != null;
      final temp = extra.bottom ?? extra.mid;
      return OceanSnapshot(
        region: region,
        stationName: extra.name,
        waterTemp: temp,
        layer: usesBottom ? '저층' : '중층',
        sevenDayTemps: [temp],
        sevenDayLabels: const ['오늘'],
        source: 'NIFS RISA (mock, 실시간 값만 제공)',
        hasTrendHistory: false,
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
      redTideStatus: '없음',
      sevenDayTemps: series,
      sevenDayLabels: _lastSevenDayLabels(),
      source: '바다누리 해양정보 · NIFS RISA (mock)',
      hasTrendHistory: true,
    );
  }

  /// Surface water is a bit warmer than mid/bottom depth in this mock
  /// world, so 표층 readings (never returned by [fetchStations], but shown
  /// separately on MyPage) are derived as an offset from the depth value.
  static const _surfaceOffset = 0.4;

  @override
  Future<List<OceanObservation>> fetchRealtime({String? station}) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final extra = _extraStations[station];
    if (extra != null) {
      return [
        OceanObservation(
          stationCode: station!,
          stationName: extra.name,
          observedDate: _today(),
          observedTime: '12:00',
          layer: '표층',
          waterTempC: extra.mid + _surfaceOffset,
          status: '정상',
        ),
        OceanObservation(
          stationCode: station,
          stationName: extra.name,
          observedDate: _today(),
          observedTime: '12:00',
          layer: '중층',
          waterTempC: extra.mid,
          status: '정상',
        ),
        if (extra.bottom != null)
          OceanObservation(
            stationCode: station,
            stationName: extra.name,
            observedDate: _today(),
            observedTime: '12:00',
            layer: '저층',
            waterTempC: extra.bottom,
            status: '정상',
          ),
      ];
    }
    final bottomTemp = (_tempSeries[station ?? '001'] ?? _tempSeries['001']!).last;
    return [
      OceanObservation(
        stationCode: station ?? '001',
        stationName: station == '002' ? '해남' : '완도',
        observedDate: _today(),
        observedTime: '12:00',
        layer: '표층',
        waterTempC: bottomTemp + _surfaceOffset,
        status: '정상',
      ),
      OceanObservation(
        stationCode: station ?? '001',
        stationName: station == '002' ? '해남' : '완도',
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
    return [
      const OceanStation(code: '001', name: '완도', layers: ['저층']),
      const OceanStation(code: '002', name: '해남', layers: ['저층']),
      for (final entry in _extraStations.entries)
        OceanStation(
          code: entry.key,
          name: entry.value.name,
          layers: [if (entry.value.bottom != null) '저층', '중층'],
        ),
    ];
  }

  static List<String> _lastSevenDayLabels() {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return '${d.month}/${d.day}';
    });
  }

  static String _today() {
    final d = DateTime.now();
    return '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
  }
}

class _MockStationLayers {
  const _MockStationLayers({required this.name, required this.mid, this.bottom});
  final String name;
  final double mid;
  final double? bottom;
}
