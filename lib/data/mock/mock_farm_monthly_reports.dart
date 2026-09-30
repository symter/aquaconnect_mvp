import '../models/farm.dart';
import '../models/farm_monthly_report.dart';
import '../models/monthly_report.dart';
import '../models/report.dart';
import '../models/risk_level.dart';

/// 양식장 관리 리포트 예시 (2026년 9월). 첨부된 `양식장_관리리포트_성산B`
/// 양식을 mock 양식장(신일수산 1양식장·미래수산·청해양식장)에 맞춰 채웠다.
/// 예시가 없는 양식장은 [FarmMonthlyReports.fallback]으로 리포트 요약만
/// 담아 만든다. 서버 API가 생기면 이 파일을 대체한다.
class FarmMonthlyReports {
  FarmMonthlyReports._();

  static const _year = 2026, _month = 9;
  static const _weeks = [1, 7, 14, 21, 28];
  static const _days = [3, 7, 10, 14, 17, 21, 24, 28];
  static final _issuedAt = DateTime(2026, 10, 1);
  static const _orgContact = '평일 09:00~18:00 · 061-000-0000';
  static const _managerPhone = '010-0000-0000';

  static FarmMonthlyReport forFarm(Farm farm, {Report? report, required String orgName}) {
    final build = _examples[farm.id];
    return build != null ? build(farm, orgName) : fallback(farm, report: report, orgName: orgName);
  }

  static final Map<String, FarmMonthlyReport Function(Farm, String)> _examples = {
    'farm-sinil-1': _sinil,
    'farm-mirae': _mirae,
    'farm-cheonghae': _cheonghae,
  };

  static FarmMonthlyReport _sinil(Farm farm, String orgName) => FarmMonthlyReport(
        orgName: orgName,
        farmName: farm.name,
        year: _year,
        month: _month,
        seaArea: '완도 해역 (노화)',
        species: '우럭',
        tanksLabel: '3개 (1수조 ~ 3수조)',
        managerName: farm.assignedMemberName ?? '담당 관리사',
        issuedAt: _issuedAt,
        status: FarmReportStatus.urgent,
        statusSummary: '9월 하순부터 **3수조 폐사가 늘고 있고**, 3수조 DO가 **기준(5 mg/L) 아래로 두 번** 내려갔습니다. '
            '10월 2일 재방문해 원인을 확인하겠습니다. 그 전까지 아래 권고를 꼭 지켜 주세요.',
        tiles: const [
          ReportTile(label: '방문·예찰', value: '3회', note: '9/4, 9/18, 9/29'),
          ReportTile(label: '검사', value: '3건', note: '1건 경과 관찰', tone: ReportTone.bad),
          ReportTile(label: 'DO·pH 측정', value: '16회', note: '기준 밖 2회', tone: ReportTone.bad),
          ReportTile(label: '약품·자재 배달', value: '2건', note: '비타민제 C 외 1건'),
        ],
        opinion: const [
          '9/18 방문 때 3수조에서 유영이 둔한 개체가 보였고, 9/25 질병 검사(표본 5미)에서 아가미가 약간 창백했습니다. '
              '9/22 VHSV 검사는 음성이어서 바이러스보다는 수질 스트레스 쪽으로 보고 있습니다.',
          '한 달 동안 3수조 DO가 6.4에서 4.7 mg/L까지 꾸준히 내려갔고, 9/24부터는 기준(5 mg/L) 아래였습니다. '
              '9/29 폐사 12마리를 확인하고 시료를 채취했으며, 결과가 나오면 바로 알려 드리겠습니다.',
        ],
        recommendations: const [
          ReportRecommendation('사료량 줄이기', '재방문 전까지 3수조는 평소의 70% 수준으로 급이해 주세요.'),
          ReportRecommendation('3수조 산소 공급', '환수량을 늘리고 산소 공급기를 상시 가동해 DO를 5.5 mg/L 이상으로 유지해 주세요.'),
          ReportRecommendation('DO 매일 측정', '3수조는 10월 동안 매일 아침 측정하고, 5 mg/L 아래면 바로 연락 주세요.'),
          ReportRecommendation('폐사어 기록', '폐사어는 수조별 마릿수를 적고 사진과 함께 앱에 남겨 주세요.'),
        ],
        nextItems: const [
          ReportNextItem('재방문', '10월 2일 (금)', '3수조 원인 확인'),
          ReportNextItem('시료 검사 결과', '10월 5일까지', '결과는 바로 연락드립니다'),
          ReportNextItem('DO·pH 측정', '3수조 매일', '1수조는 주 2회 유지'),
        ],
        seaWeeks: _weeks,
        seaTemps: const [27.8, 27.1, 26.2, 25.4, 24.9],
        seaSalinities: const [31.6, 31.8, 32.0, 32.1, 32.3],
        seaSummary: '수온은 한 달 동안 2.9°C 내려갔고, 염도는 31.6 → 32.3 psu로 거의 변화가 없었습니다.',
        alerts: const [
          ReportAlert('적조', '발령 없음'),
          ReportAlert('고수온', '9/9 해제'),
          ReportAlert('저수온', '발령 없음'),
          ReportAlert('태풍', '영향 없음'),
        ],
        tanks: const [
          ReportTankSeries(
              name: '1수조',
              days: _days,
              doValues: [7.0, 6.9, 6.7, 6.6, 6.4, 6.3, 6.1, 6.0],
              phValues: [8.0, 8.0, 7.9, 8.0, 7.9, 7.9, 7.9, 7.8]),
          ReportTankSeries(
              name: '3수조',
              days: _days,
              doValues: [6.4, 6.1, 5.9, 5.6, 5.3, 5.1, 4.8, 4.7],
              phValues: [8.0, 7.9, 7.9, 7.8, 7.8, 7.7, 7.6, 7.6]),
        ],
        waterSummary: '3수조 DO가 9/24부터 기준(5 mg/L) 아래입니다. pH는 7.6~8.0으로 기준 안이지만 조금씩 내려가고 있습니다.',
        logs: const [
          ReportLogEntry(4, MonthlyEventType.patrol, '1수조', '정기 예찰 — 외관·섭이 이상 없음'),
          ReportLogEntry(10, MonthlyEventType.delivery, '-', '비타민제 C 20kg 배달 완료'),
          ReportLogEntry(18, MonthlyEventType.patrol, '3수조', '유영 둔화 개체 확인 — 수질 추적 권고'),
          ReportLogEntry(18, MonthlyEventType.exam, '2수조', '우럭 표본 10미 — 외부·해부 이상 없음', label: '정기 검사'),
          ReportLogEntry(22, MonthlyEventType.diag, '3수조', 'VHSV 음성, 현미경 특이 소견 없음'),
          ReportLogEntry(25, MonthlyEventType.exam, '3수조', '우럭 표본 5미 — 아가미 약간 창백, 경과 관찰', label: '질병 검사'),
          ReportLogEntry(26, MonthlyEventType.delivery, '-', '소독제 E 20L 배달 완료'),
          ReportLogEntry(29, MonthlyEventType.patrol, '3수조', '폐사 12마리 확인 — 시료 채취'),
        ],
        exams: const [
          ReportExamRow(18, MonthlyEventType.exam, '정기 검사', '2수조', '우럭 표본 10미 · 외부·해부', '이상 없음'),
          ReportExamRow(22, MonthlyEventType.diag, '바이러스 진단', '3수조', 'VHSV · 현미경 특이 소견 없음', '음성'),
          ReportExamRow(25, MonthlyEventType.exam, '질병 검사', '3수조', '우럭 표본 5미 · 아가미', '경과 관찰', ok: false),
        ],
        deliveries: const [
          ReportDeliveryRow(10, '비타민제 C', '20kg', '면역력 보강'),
          ReportDeliveryRow(26, '소독제 E', '20L', '수조·기구 소독'),
        ],
        managerPhone: _managerPhone,
        orgContact: _orgContact,
      );

  static FarmMonthlyReport _mirae(Farm farm, String orgName) => FarmMonthlyReport(
        orgName: orgName,
        farmName: farm.name,
        year: _year,
        month: _month,
        seaArea: '완도 해역 (금일)',
        species: '넙치',
        tanksLabel: '2개 (1수조 ~ 2수조)',
        managerName: farm.assignedMemberName ?? '담당 관리사',
        issuedAt: _issuedAt,
        status: FarmReportStatus.urgent,
        statusSummary: '9월 말 **2수조에서 폐사 신고**가 있었고, 수면 근처에서 헤엄치는 개체가 많이 보였습니다. '
            '**시료 검사 결과가 나올 때까지** 2수조 넙치는 다른 수조로 옮기지 말아 주세요.',
        tiles: const [
          ReportTile(label: '방문·예찰', value: '2회', note: '9/5, 9/19'),
          ReportTile(label: '검사', value: '2건', note: '1건 결과 대기', tone: ReportTone.bad),
          ReportTile(label: 'DO·pH 측정', value: '16회', note: '기준 밖 1회', tone: ReportTone.bad),
          ReportTile(label: '약품·자재 배달', value: '1건', note: '영양제 F 15kg'),
        ],
        opinion: const [
          '9/19 방문 때 두 수조 모두 외관은 양호했지만, 2수조는 섭이가 조금 떨어져 있었습니다. '
              '9/29 폐사 신고 후 받은 사진에서 수면 근처 유영 개체가 여럿 보여, 시료를 받아 질병 검사를 진행하고 있습니다.',
          '2수조 pH가 9/28 7.4로 처음 기준(7.5) 아래로 내려갔습니다. 환수로 바로 회복되는지 함께 확인하겠습니다.',
        ],
        recommendations: const [
          ReportRecommendation('2수조 이동 금지', '검사 결과가 나올 때까지 2수조 넙치와 기구를 다른 수조에 쓰지 말아 주세요.'),
          ReportRecommendation('환수 늘리기', '2수조 환수량을 평소보다 30% 늘리고, pH를 하루 두 번 측정해 주세요.'),
          ReportRecommendation('폐사어 보관', '추가 폐사어는 비닐에 담아 냉장 보관해 주시면 방문 때 가져가겠습니다.'),
        ],
        nextItems: const [
          ReportNextItem('검사 결과', '10월 2일 (금)', '결과는 바로 연락드립니다'),
          ReportNextItem('재방문', '10월 첫째 주', '결과에 따라 일정 조정'),
          ReportNextItem('DO·pH 측정', '2수조 하루 2회', '1수조는 주 2회 유지'),
        ],
        seaWeeks: _weeks,
        seaTemps: const [27.6, 26.9, 26.0, 25.2, 24.7],
        seaSalinities: const [31.5, 31.7, 31.9, 32.0, 32.2],
        seaSummary: '수온은 한 달 동안 2.9°C 내려갔고, 염도는 31.5 → 32.2 psu로 거의 변화가 없었습니다.',
        alerts: const [
          ReportAlert('적조', '발령 없음'),
          ReportAlert('고수온', '9/9 해제'),
          ReportAlert('저수온', '발령 없음'),
          ReportAlert('태풍', '영향 없음'),
        ],
        tanks: const [
          ReportTankSeries(
              name: '1수조',
              days: _days,
              doValues: [7.2, 7.0, 7.1, 6.9, 6.8, 6.8, 6.6, 6.5],
              phValues: [8.1, 8.0, 8.0, 8.1, 8.0, 8.0, 7.9, 8.0]),
          ReportTankSeries(
              name: '2수조',
              days: _days,
              doValues: [6.9, 6.7, 6.6, 6.4, 6.2, 6.0, 5.8, 5.6],
              phValues: [8.0, 7.9, 7.9, 7.8, 7.7, 7.6, 7.5, 7.4]),
        ],
        waterSummary: '2수조 pH가 9/28 7.4로 기준(7.5~8.5) 아래였습니다. DO는 모두 기준 안이지만 2수조가 조금씩 내려가고 있습니다.',
        logs: const [
          ReportLogEntry(5, MonthlyEventType.patrol, '1수조', '정기 예찰 — 외관·유영 이상 없음'),
          ReportLogEntry(12, MonthlyEventType.delivery, '-', '영양제 F 15kg 배달 완료'),
          ReportLogEntry(19, MonthlyEventType.patrol, '2수조', '섭이 저하 관찰 — 수질 추적 권고'),
          ReportLogEntry(19, MonthlyEventType.diag, '2수조', 'VHSV 음성, 현미경 특이 소견 없음'),
          ReportLogEntry(29, MonthlyEventType.exam, '2수조', '폐사어 3미 — 검사 중', label: '폐사 원인 검사'),
        ],
        exams: const [
          ReportExamRow(19, MonthlyEventType.diag, '바이러스 진단', '2수조', 'VHSV · 현미경 특이 소견 없음', '음성'),
          ReportExamRow(29, MonthlyEventType.exam, '폐사 원인 검사', '2수조', '넙치 폐사어 3미 · 세균 배양', '검사 중', ok: false),
        ],
        deliveries: const [
          ReportDeliveryRow(12, '영양제 F', '15kg', '섭이 회복 보조'),
        ],
        managerPhone: _managerPhone,
        orgContact: _orgContact,
      );

  static FarmMonthlyReport _cheonghae(Farm farm, String orgName) => FarmMonthlyReport(
        orgName: orgName,
        farmName: farm.name,
        year: _year,
        month: _month,
        seaArea: '해남 해역 (화산)',
        species: '넙치',
        tanksLabel: '3개 (1동-01 ~ 1동-03)',
        managerName: farm.assignedMemberName ?? '담당 관리사',
        issuedAt: _issuedAt,
        status: FarmReportStatus.watch,
        statusSummary: '9월 검사는 **모두 이상 없음**이었지만, 하순에 **섭이 감소**가 보고되었습니다. '
            '수온이 내려가는 시기라 자연스러운 변화일 수 있어, 10월 첫 방문 때 다시 확인하겠습니다.',
        tiles: const [
          ReportTile(label: '방문·예찰', value: '2회', note: '9/9, 9/28'),
          ReportTile(label: '검사', value: '2건', note: '모두 이상 없음', tone: ReportTone.good),
          ReportTile(label: 'DO·pH 측정', value: '16회', note: '기준 밖 0회', tone: ReportTone.good),
          ReportTile(label: '약품·자재 배달', value: '1건', note: '비타민제 C 10kg'),
        ],
        opinion: const [
          '9/16 정기 검사(표본 10미)와 9/22 VHSV 검사에서 특이 소견이 없었습니다. '
              '9/28 방문 때 1동-02에서 섭이가 평소보다 20% 정도 줄어든 것을 확인했지만, 외관과 유영은 정상이었습니다.',
          '해남 해역 수온이 27.2°C에서 24.5°C로 내려가면서 섭이가 줄어드는 시기입니다. '
              '수조 DO·pH는 한 달 내내 기준 안이었습니다.',
        ],
        recommendations: const [
          ReportRecommendation('급이량 조절', '섭이가 줄면 억지로 먹이지 말고 남는 사료를 바로 걷어 주세요.'),
          ReportRecommendation('섭이 기록', '1동-02는 매일 급이량과 남은 양을 적어 주세요.'),
          ReportRecommendation('이상 행동 연락', '체색 변화나 폐사가 보이면 사진과 함께 바로 연락 주세요.'),
        ],
        nextItems: const [
          ReportNextItem('다음 정기 방문', '10월 둘째 주', '날짜는 따로 연락드립니다'),
          ReportNextItem('섭이 확인', '10월 첫 방문 때', '1동-02 중심'),
          ReportNextItem('DO·pH 측정', '주 2회 유지', '1동-01, 1동-02'),
        ],
        seaWeeks: _weeks,
        seaTemps: const [27.2, 26.5, 25.6, 24.9, 24.5],
        seaSalinities: const [31.2, 31.4, 31.5, 31.7, 31.8],
        seaSummary: '수온은 한 달 동안 2.7°C 내려갔고, 염도는 31.2 → 31.8 psu로 거의 변화가 없었습니다.',
        alerts: const [
          ReportAlert('적조', '발령 없음'),
          ReportAlert('고수온', '9/9 해제'),
          ReportAlert('저수온', '발령 없음'),
          ReportAlert('태풍', '영향 없음'),
        ],
        tanks: const [
          ReportTankSeries(
              name: '1동-01',
              days: _days,
              doValues: [7.2, 7.1, 7.0, 6.9, 6.9, 6.8, 6.7, 6.7],
              phValues: [8.0, 8.0, 8.1, 8.0, 8.0, 8.1, 8.0, 8.0]),
          ReportTankSeries(
              name: '1동-02',
              days: _days,
              doValues: [6.9, 6.8, 6.8, 6.6, 6.5, 6.5, 6.4, 6.3],
              phValues: [8.1, 8.0, 8.0, 8.0, 7.9, 8.0, 7.9, 7.9]),
        ],
        waterSummary: '16회 측정 모두 기준 안입니다. pH는 7.9~8.1 사이로 안정적이었습니다.',
        logs: const [
          ReportLogEntry(6, MonthlyEventType.delivery, '-', '비타민제 C 10kg 배달 완료'),
          ReportLogEntry(9, MonthlyEventType.patrol, '1동-01', '정기 예찰 — 외관·유영 이상 없음'),
          ReportLogEntry(16, MonthlyEventType.exam, '1동-03', '넙치 표본 10미 — 외부·해부 이상 없음', label: '정기 검사'),
          ReportLogEntry(22, MonthlyEventType.diag, '1동-02', 'VHSV 음성, 현미경 특이 소견 없음'),
          ReportLogEntry(28, MonthlyEventType.patrol, '1동-02', '섭이 감소 확인 — 외관·유영 정상'),
        ],
        exams: const [
          ReportExamRow(16, MonthlyEventType.exam, '정기 검사', '1동-03', '넙치 표본 10미 · 외부·해부', '이상 없음'),
          ReportExamRow(22, MonthlyEventType.diag, '바이러스 진단', '1동-02', 'VHSV · 현미경 특이 소견 없음', '음성'),
        ],
        deliveries: const [
          ReportDeliveryRow(6, '비타민제 C', '10kg', '면역력 보강'),
        ],
        managerPhone: _managerPhone,
        orgContact: _orgContact,
      );

  /// 예시가 없는 양식장: 규칙 기반 리포트([Report])의 요약·소견·후속 조치만
  /// 담는다. 해양환경·DO·pH·기록 표는 데이터가 없어 빠진다.
  static FarmMonthlyReport fallback(Farm farm, {Report? report, required String orgName}) {
    final now = DateTime.now();
    final status = switch (report?.riskLevel ?? farm.riskLevel) {
      RiskLevel.danger => FarmReportStatus.urgent,
      RiskLevel.warning => FarmReportStatus.watch,
      RiskLevel.good => FarmReportStatus.good,
    };
    return FarmMonthlyReport(
      orgName: orgName,
      farmName: farm.name,
      year: now.year,
      month: now.month,
      seaArea: '${farm.region} 해역',
      species: '-',
      tanksLabel: '-',
      managerName: farm.assignedMemberName ?? '담당 관리사',
      issuedAt: report?.generatedAt ?? now,
      status: status,
      statusSummary: report?.headline ?? farm.headline,
      tiles: [
        if (report != null) ...[
          ReportTile(label: '주간 폐사', value: '${report.weeklyMortality}마리', note: '최근 7일 누적'),
          ReportTile(label: '평균 수온', value: '${report.avgTemp.toStringAsFixed(1)}°C', note: report.periodLabel),
        ],
        ReportTile(label: '최근 방문', value: '${farm.lastVisitDays}일 전', note: farm.assignedMemberName ?? '담당 관리사'),
        ReportTile(label: '현재 수온', value: '${farm.waterTemp.toStringAsFixed(1)}°C', note: '${farm.nearestStationName} 관측소'),
      ],
      opinion: [if (report != null) report.summary, ...?report?.findings],
      recommendations: [for (final f in report?.followUps ?? const <String>[]) ReportRecommendation(f, '')],
      nextItems: const [],
      managerPhone: _managerPhone,
      orgContact: _orgContact,
    );
  }
}
