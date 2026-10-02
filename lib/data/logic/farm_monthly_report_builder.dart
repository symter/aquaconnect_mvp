import '../models/farm.dart';
import '../models/farm_monthly_report.dart';
import '../models/report.dart';
import '../models/risk_level.dart';

/// Builds the farm-facing 관리 리포트 ([FarmMonthlyReport]) from what the app
/// actually records: the latest rule-based [Report] plus the farm row. There
/// is no data yet for sea salinity, tank DO·pH, exam or delivery logs, so
/// those sections stay empty and `buildFarmReportHtml` leaves them out.
class FarmMonthlyReportBuilder {
  FarmMonthlyReportBuilder._();

  static FarmMonthlyReport build(
    Farm farm, {
    Report? report,
    required String orgName,
    String? managerPhone,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final status = switch (report?.riskLevel ?? farm.riskLevel) {
      RiskLevel.danger => FarmReportStatus.urgent,
      RiskLevel.warning => FarmReportStatus.watch,
      RiskLevel.good => FarmReportStatus.good,
    };
    final manager = farm.assignedMemberName ?? '담당 관리사';
    final lastVisit = report?.lastVisitDays ?? farm.lastVisitDays;
    final avgTemp = report?.avgTemp;
    final waterTemp = farm.waterTemp;
    final issued = report?.generatedAt ?? today;
    final from = issued.subtract(const Duration(days: 6));
    final summary = report?.headline ?? (farm.headline.isEmpty ? '아직 생성된 리포트가 없습니다.' : farm.headline);

    return FarmMonthlyReport(
      orgName: orgName,
      farmName: farm.name,
      year: today.year,
      month: today.month,
      seaArea: farm.region.isEmpty ? '-' : '${farm.region} 해역',
      species: '-',
      tanksLabel: '-',
      managerName: manager,
      issuedAt: issued,
      // The rule-based report covers the last 7 days, not a calendar month.
      periodLabel: '최근 7일 (${from.month}/${from.day} ~ ${issued.month}/${issued.day}) 리포트',
      status: status,
      statusSummary: summary,
      tiles: [
        if (report != null) ...[
          ReportTile(
            label: '주간 폐사',
            value: '${report.weeklyMortality}마리',
            note: '최근 7일 누적',
            tone: report.weeklyMortality > 0 ? ReportTone.bad : ReportTone.plain,
          ),
          ReportTile(
            label: '평균 수온',
            value: avgTemp == null ? '정보 없음' : '${avgTemp.toStringAsFixed(1)}°C',
            note: report.periodLabel,
          ),
        ],
        ReportTile(label: '최근 방문', value: switch (lastVisit) {
            null => '기록 없음',
            0 => '오늘',
            _ => '$lastVisit일 전',
          }, note: manager),
        ReportTile(
          label: '현재 수온',
          value: waterTemp == null ? '정보 없음' : '${waterTemp.toStringAsFixed(1)}°C',
          note: farm.nearestStationName.isEmpty ? '-' : '${farm.nearestStationName} 관측소',
        ),
      ],
      opinion: [if (report != null) report.summary, ...?report?.findings],
      recommendations: [for (final f in report?.followUps ?? const <String>[]) ReportRecommendation(f, '')],
      nextItems: const [],
      managerPhone: (managerPhone?.isNotEmpty ?? false) ? managerPhone! : '연락처 미등록',
      orgContact: "공유 링크의 '문의하기'로 메모를 남기실 수 있습니다",
    );
  }
}
