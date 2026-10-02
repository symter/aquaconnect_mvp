import 'package:flutter_test/flutter_test.dart';

import 'package:aquaconnect_mvp/data/logic/farm_monthly_report_builder.dart';
import 'package:aquaconnect_mvp/data/models/farm.dart';
import 'package:aquaconnect_mvp/data/models/report.dart';
import 'package:aquaconnect_mvp/data/models/risk_level.dart';
import 'package:aquaconnect_mvp/features/reports/farm_report_html.dart';

void main() {
  const farm = Farm(
    id: 'f1',
    orgId: 'o1',
    name: '테스트양식장',
    region: '완도',
    address: '완도군 노화읍',
    nearestStationCode: 'wn087',
    nearestStationName: '노화',
    riskLevel: RiskLevel.danger,
    headline: '최근 7일 폐사 20마리',
    waterTemp: 24.0,
    lastVisitDays: 2,
    assignedMemberName: '이동길',
  );
  final report = Report(
    id: 'r1',
    farmId: 'f1',
    periodLabel: '이번 주',
    riskLevel: RiskLevel.danger,
    headline: '고수온·폐사 급증 — 긴급 확인 필요',
    summary: '지난 7일 대비 폐사와 수온이 함께 상승했습니다.',
    weeklyMortality: 20,
    avgTemp: 24.0,
    lastVisitDays: 2,
    findings: const ['최근 7일간 누적 폐사 20마리 (기록된 메모 기준)'],
    followUps: const ['즉시 방문 및 폐사체 시료 채취를 진행하세요'],
    mortalityTrend: const [0, 0, 0, 0, 0, 0, 20],
    tempTrend: const [24, 24, 24, 24, 24, 24, 24],
    dayLabels: const ['9/24', '9/25', '9/26', '9/27', '9/28', '9/29', '9/30'],
    generatedAt: DateTime(2026, 9, 30, 9),
  );

  test('실데이터 리포트는 해양환경·수조 쪽 없이 2쪽으로 나온다', () {
    final html = buildFarmReportHtml(FarmMonthlyReportBuilder.build(
      farm,
      report: report,
      orgName: '해강수산질병관리원',
      managerPhone: '010-1234-5678',
      now: DateTime(2026, 9, 30),
    ));

    expect('class="page"'.allMatches(html), hasLength(2));
    expect(html, contains('현재 상태: 긴급 관리 필요'));
    expect(html, contains('최근 7일 (9/24 ~ 9/30) 리포트'));
    expect(html, contains('<h3 style="margin-top:12px">관리 권고</h3>'));
    expect(html, isNot(contains('월간 리포트')));
    expect(html, contains('20마리'));
    expect(html, contains('즉시 방문 및 폐사체 시료 채취를 진행하세요'));
    expect(html, contains('010-1234-5678'));
    expect(html, isNot(contains('해양환경 데이터')));
    expect(html, isNot(contains('010-0000-0000')));
  });

  test('데이터가 없으면 0 대신 정보 없음·기록 없음·연락처 미등록', () {
    const bare = Farm(
      id: 'f2',
      orgId: 'o1',
      name: '새양식장',
      region: '',
      address: '',
      nearestStationCode: '',
      nearestStationName: '',
      riskLevel: RiskLevel.good,
      headline: '',
    );
    final html = buildFarmReportHtml(FarmMonthlyReportBuilder.build(bare, orgName: '해강수산질병관리원'));

    expect(html, contains('정보 없음'));
    expect(html, contains('기록 없음'));
    expect(html, contains('연락처 미등록'));
    expect(html, contains('아직 생성된 리포트가 없습니다.'));
    expect(html, isNot(contains('0.0°C')));
  });

  test('문장 속 HTML 특수문자는 이스케이프된다', () {
    final html = buildFarmReportHtml(
      FarmMonthlyReportBuilder.build(farm.copyWith(name: '<img src=x>'), report: report, orgName: 'A&B'),
    );

    expect(html, isNot(contains('<img src=x>')));
    expect(html, contains('<h1>&lt;img src=x&gt;</h1>'));
    expect(html, contains('A&amp;B'));
  });
}
