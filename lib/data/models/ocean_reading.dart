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
/// station picker. [layers] holds whichever of '중층'/'저층' this station
/// publishes — surface-only ('표층') stations are filtered out upstream so
/// every selectable station always has a mid- or bottom-layer reading.
class OceanStation {
  const OceanStation({required this.code, required this.name, required this.layers});

  final String code;
  final String name;
  final List<String> layers;
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

/// Aggregated environment snapshot used to render the 4-stat grid + 7-day
/// sparkline shown on Info / AllReport / ReportDetail.
///
/// [salinity], [dissolvedOxygen] and [redTideStatus] are nullable because
/// the NIFS `risaList` feed only publishes real-time water temperature —
/// those fields stay null (rendered as "정보 없음") until a richer source
/// is wired in. [sevenDayTemps] may hold fewer than 7 points in that same
/// live mode since NIFS exposes no history endpoint; [hasTrendHistory]
/// tells the UI whether the series is real history or just the live point.
class OceanSnapshot {
  const OceanSnapshot({
    required this.region,
    required this.stationName,
    required this.waterTemp,
    required this.sevenDayTemps,
    required this.sevenDayLabels,
    required this.source,
    required this.hasTrendHistory,
    this.salinity,
    this.redTideStatus,
    this.dissolvedOxygen,
    this.layer,
  });

  final String region;
  final String stationName;
  final double waterTemp;
  final double? salinity;
  final String? redTideStatus;
  final double? dissolvedOxygen;
  final List<double> sevenDayTemps;
  final List<String> sevenDayLabels;
  final String source;
  final bool hasTrendHistory;

  /// Which depth [waterTemp] was measured at ('표층'/'중층'/'저층'), when
  /// known. Null only for aggregate/synthetic snapshots (e.g. the
  /// multi-farm average on AllReport) that don't correspond to one reading.
  final String? layer;
}
