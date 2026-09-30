import 'monthly_report.dart';

/// 수산질병관리원이 양식장(어가)에 보내는 월간 관리 리포트.
///
/// 앱(홈 → 양식장)과 공유 링크(`/r/:token`) 모두 이 데이터를
/// `buildFarmReportHtml`로 A4 3쪽 HTML로 만들어 보여 주고, 같은 HTML을
/// 인쇄해 PDF로 저장한다. 문장 필드의 `**굵게**`는 HTML에서 `<b>`가 된다.
enum FarmReportStatus {
  good('정상'),
  watch('관찰 필요'),
  urgent('긴급 관리 필요');

  const FarmReportStatus(this.label);
  final String label;
}

enum ReportTone { plain, good, bad }

class ReportTile {
  const ReportTile({required this.label, required this.value, required this.note, this.tone = ReportTone.plain});

  final String label;
  final String value;
  final String note;
  final ReportTone tone;
}

class ReportRecommendation {
  const ReportRecommendation(this.title, this.body);

  final String title;
  final String body;
}

class ReportNextItem {
  const ReportNextItem(this.label, this.value, this.note);

  final String label;
  final String value;
  final String note;
}

class ReportAlert {
  const ReportAlert(this.label, this.value, {this.ok = true});

  final String label;
  final String value;
  final bool ok;
}

class ReportTankSeries {
  const ReportTankSeries({required this.name, required this.days, required this.doValues, required this.phValues});

  final String name;
  final List<int> days;
  final List<double> doValues;
  final List<double> phValues;
}

class ReportLogEntry {
  const ReportLogEntry(this.day, this.type, this.tank, this.content, {this.label});

  final int day;
  final MonthlyEventType type;
  final String tank;
  final String content;

  /// 칩 문구. 없으면 [MonthlyEventType.label].
  final String? label;
}

class ReportExamRow {
  const ReportExamRow(this.day, this.type, this.label, this.tank, this.target, this.result, {this.ok = true});

  final int day;
  final MonthlyEventType type;
  final String label;
  final String tank;
  final String target;
  final String result;
  final bool ok;
}

class ReportDeliveryRow {
  const ReportDeliveryRow(this.day, this.item, this.qty, this.purpose, {this.done = true});

  final int day;
  final String item;
  final String qty;
  final String purpose;
  final bool done;
}

class FarmMonthlyReport {
  const FarmMonthlyReport({
    required this.orgName,
    required this.farmName,
    required this.year,
    required this.month,
    required this.seaArea,
    required this.species,
    required this.tanksLabel,
    required this.managerName,
    required this.issuedAt,
    required this.status,
    required this.statusSummary,
    required this.tiles,
    required this.opinion,
    required this.recommendations,
    required this.nextItems,
    required this.managerPhone,
    required this.orgContact,
    this.seaWeeks = const [],
    this.seaTemps = const [],
    this.seaSalinities = const [],
    this.seaSummary = '',
    this.alerts = const [],
    this.tanks = const [],
    this.waterSummary = '',
    this.logs = const [],
    this.exams = const [],
    this.deliveries = const [],
  });

  final String orgName;
  final String farmName;
  final int year;
  final int month;
  final String seaArea;
  final String species;
  final String tanksLabel;
  final String managerName;
  final DateTime issuedAt;

  final FarmReportStatus status;
  final String statusSummary;
  final List<ReportTile> tiles;
  final List<String> opinion;
  final List<ReportRecommendation> recommendations;
  final List<ReportNextItem> nextItems;

  final List<int> seaWeeks;
  final List<double> seaTemps;
  final List<double> seaSalinities;
  final String seaSummary;
  final List<ReportAlert> alerts;

  final List<ReportTankSeries> tanks;
  final String waterSummary;

  final List<ReportLogEntry> logs;
  final List<ReportExamRow> exams;
  final List<ReportDeliveryRow> deliveries;

  final String managerPhone;

  /// 예: "평일 09:00~18:00 · 061-000-0000"
  final String orgContact;

  String get title => '$farmName 관리 리포트 · $year년 $month월';
}
