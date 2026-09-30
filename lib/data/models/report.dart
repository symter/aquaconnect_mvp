import 'risk_level.dart';

/// A generated, rule-based farm report snapshot.
///
/// Labeled "AI 정리 소견" in the UI per the design, but computed by
/// [ReportGenerator] from accumulated memos + ocean readings — see
/// `lib/data/logic/report_generator.dart` for the actual (non-LLM) logic.
class Report {
  const Report({
    required this.id,
    required this.farmId,
    required this.periodLabel,
    required this.riskLevel,
    required this.headline,
    required this.summary,
    required this.weeklyMortality,
    required this.avgTemp,
    required this.lastVisitDays,
    required this.findings,
    required this.followUps,
    required this.mortalityTrend,
    required this.tempTrend,
    required this.dayLabels,
    required this.generatedAt,
  });

  final String id;
  final String farmId;
  final String periodLabel;
  final RiskLevel riskLevel;
  final String headline;
  final String summary;
  final int weeklyMortality;
  /// Null when no water-temp reading was available at generation time.
  final double? avgTemp;

  /// Null when no visit memo had been recorded at generation time.
  final int? lastVisitDays;
  final List<String> findings;
  final List<String> followUps;
  final List<double> mortalityTrend;
  final List<double> tempTrend;
  final List<String> dayLabels;
  final DateTime generatedAt;

  factory Report.fromJson(Map<String, dynamic> json) => Report(
        id: json['id'] as String,
        farmId: json['farmId'] as String,
        periodLabel: json['periodLabel'] as String,
        riskLevel: RiskLevel.fromKey(json['riskLevel'] as String),
        headline: json['headline'] as String,
        summary: json['summary'] as String,
        weeklyMortality: (json['weeklyMortality'] as num).toInt(),
        avgTemp: (json['avgTemp'] as num?)?.toDouble(),
        lastVisitDays: (json['lastVisitDays'] as num?)?.toInt(),
        findings: (json['findings'] as List<dynamic>? ?? const []).cast<String>(),
        followUps: (json['followUps'] as List<dynamic>? ?? const []).cast<String>(),
        mortalityTrend:
            (json['mortalityTrend'] as List<dynamic>? ?? const []).map((e) => (e as num).toDouble()).toList(),
        tempTrend: (json['tempTrend'] as List<dynamic>? ?? const []).map((e) => (e as num).toDouble()).toList(),
        dayLabels: (json['dayLabels'] as List<dynamic>? ?? const []).cast<String>(),
        generatedAt: DateTime.parse(json['generatedAt'] as String),
      );
}
