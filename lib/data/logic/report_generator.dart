import '../models/farm.dart';
import '../models/memo.dart';
import '../models/ocean_reading.dart';
import '../models/report.dart';
import '../models/risk_level.dart';

/// Rule-based report builder.
///
/// The UI labels the output "AI 정리 소견" (per the approved design copy),
/// but this MVP does not call any LLM — it combines accumulated memos with
/// ocean readings using fixed thresholds. Swapping in a real model later
/// only requires replacing [ReportGenerator.generate] with an async call
/// that returns the same [Report] shape.
class ReportGenerator {
  ReportGenerator._();

  static final _mortalityTagPattern = RegExp(r'폐사\s*(\d+)\s*마리');

  static Report generate({
    required Farm farm,
    required List<Memo> farmMemos,
    required OceanSnapshot? ocean,
    required DateTime now,
  }) {
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final recentMemos = farmMemos.where((m) => m.createdAt.isAfter(sevenDaysAgo)).toList();

    final dayLabels = (ocean != null && ocean.sevenDayLabels.length == 7)
        ? ocean.sevenDayLabels
        : _lastSevenDayLabels(now);
    // No reading at all (NIFS down / station without data, and no earlier
    // reading stored on the farm) leaves the trend empty rather than
    // inventing a temperature.
    final currentTemp = ocean?.waterTemp ?? farm.waterTemp;
    final List<double> tempTrend = (ocean != null && ocean.sevenDayTemps.length == 7)
        ? ocean.sevenDayTemps
        : (currentTemp == null ? const [] : List.filled(7, currentTemp));
    final mortalityTrend = _mortalityByDay(recentMemos, now);

    final weeklyMortality = mortalityTrend.fold<int>(0, (sum, v) => sum + v.round());
    final double? avgTemp = tempTrend.isEmpty ? null : tempTrend.reduce((a, b) => a + b) / tempTrend.length;
    final tempDelta = tempTrend.length >= 2 ? tempTrend.last - tempTrend.first : 0.0;

    final hasAbnormalSwimming = recentMemos.any((m) => m.tags.contains('유영 이상'));
    final hasFeedingDrop = recentMemos.any((m) => m.content.contains('섭이') && m.content.contains('감소'));

    final riskLevel = _classify(weeklyMortality: weeklyMortality, avgTemp: avgTemp, tempDelta: tempDelta);

    final findings = <String>[
      if (tempDelta.abs() >= 0.4)
        '${farm.nearestStationName} 관측소 수온 최근 7일간 ${tempDelta >= 0 ? '+' : ''}${tempDelta.toStringAsFixed(1)}℃ 변화',
      if (weeklyMortality > 0) '최근 7일간 누적 폐사 $weeklyMortality마리 (기록된 메모 기준)',
      if (hasAbnormalSwimming) '유영 이상 증상이 현장 메모에 보고됨',
      if (hasFeedingDrop) '섭이량 감소가 현장 메모에 보고됨',
      if (findingsIsEmptyPlaceholder(weeklyMortality, tempDelta, hasAbnormalSwimming, hasFeedingDrop))
        '최근 7일간 특이 신호 없음',
    ];

    final followUps = _followUps(riskLevel);

    final headline = switch (riskLevel) {
      RiskLevel.danger => '고수온·폐사 급증 — 긴급 확인 필요',
      RiskLevel.warning => '고수온 지속 + 폐사 소폭 증가',
      RiskLevel.good => '특이사항 없음 — 정상 범위',
    };

    final summary = switch (riskLevel) {
      RiskLevel.danger => '지난 7일 대비 폐사와 수온이 함께 상승했습니다. 즉시 방문 및 시료 채취를 권장합니다.',
      RiskLevel.warning => avgTemp == null
          ? '지난 7일 대비 폐사 $weeklyMortality마리 — 방문 및 수질 확인을 권장합니다.'
          : '지난 7일 대비 폐사 $weeklyMortality마리, 평균 수온 ${avgTemp.toStringAsFixed(1)}℃ — 방문 및 수질 확인을 권장합니다.',
      RiskLevel.good => '최근 7일간 폐사·수온 모두 안정적인 범위입니다. 정기 모니터링을 유지하세요.',
    };

    return Report(
      id: 'report-${farm.id}-${now.millisecondsSinceEpoch}',
      farmId: farm.id,
      periodLabel: '이번 주',
      riskLevel: riskLevel,
      headline: headline,
      summary: summary,
      weeklyMortality: weeklyMortality,
      avgTemp: avgTemp,
      lastVisitDays: _lastVisitDays(farmMemos, now) ?? farm.lastVisitDays,
      findings: findings,
      followUps: followUps,
      mortalityTrend: mortalityTrend,
      tempTrend: tempTrend,
      dayLabels: dayLabels,
      generatedAt: now,
    );
  }

  static bool findingsIsEmptyPlaceholder(
    int weeklyMortality,
    double tempDelta,
    bool abnormalSwimming,
    bool feedingDrop,
  ) {
    return weeklyMortality == 0 && tempDelta.abs() < 0.4 && !abnormalSwimming && !feedingDrop;
  }

  static RiskLevel _classify({
    required int weeklyMortality,
    required double? avgTemp,
    required double tempDelta,
  }) {
    final temp = avgTemp ?? double.negativeInfinity;
    if (weeklyMortality >= 15 || temp >= 29.5) return RiskLevel.danger;
    if (weeklyMortality >= 5 || temp >= 28.0 || tempDelta >= 0.6) return RiskLevel.warning;
    return RiskLevel.good;
  }

  static List<String> _followUps(RiskLevel level) => switch (level) {
        RiskLevel.danger => const [
            '즉시 방문 및 폐사체 시료 채취를 진행하세요',
            '용존산소·수온 변화를 시간 단위로 모니터링하세요',
            '질병 검사 의뢰 여부를 검토하세요',
          ],
        RiskLevel.warning => const [
            '수질(용존산소·수온) 확인을 권장합니다',
            '3일 이내 재방문을 권장합니다',
            '폐사한 개체와 수조 상태를 사진으로 기록해두세요',
          ],
        RiskLevel.good => const [
            '정기 모니터링 일정을 유지하세요',
            '다음 정기 방문 일정대로 진행하세요',
          ],
      };

  static List<double> _mortalityByDay(List<Memo> memos, DateTime now) {
    final buckets = List<double>.filled(7, 0);
    for (final memo in memos) {
      final match = _mortalityTagPattern.firstMatch(memo.tags.join(' ')) ??
          _mortalityTagPattern.firstMatch(memo.content);
      if (match == null) continue;
      final count = int.tryParse(match.group(1) ?? '') ?? 0;
      final dayIndex = 6 - now.difference(memo.createdAt).inDays;
      if (dayIndex >= 0 && dayIndex < 7) {
        buckets[dayIndex] += count;
      }
    }
    return buckets;
  }

  /// Days since the latest institute memo (a field visit), or null if none.
  static int? _lastVisitDays(List<Memo> memos, DateTime now) {
    DateTime? latest;
    for (final m in memos) {
      if (m.authorType != MemoAuthorType.institute) continue;
      if (latest == null || m.createdAt.isAfter(latest)) latest = m.createdAt;
    }
    return latest == null ? null : now.difference(latest).inDays;
  }

  static List<String> _lastSevenDayLabels(DateTime now) {
    return List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return '${d.month}/${d.day}';
    });
  }
}
