import 'package:flutter_test/flutter_test.dart';

import 'package:aquaconnect_mvp/data/mock/mock_farm_monthly_reports.dart';
import 'package:aquaconnect_mvp/data/mock/mock_seed.dart';
import 'package:aquaconnect_mvp/features/reports/farm_report_html.dart';

void main() {
  final sinil = MockSeed.farms.firstWhere((f) => f.id == 'farm-sinil-1');

  test('예시 양식장은 A4 3쪽 리포트로 나온다', () {
    final html = buildFarmReportHtml(FarmMonthlyReports.forFarm(sinil, orgName: '해강수산질병관리원'));

    expect('class="page"'.allMatches(html), hasLength(3));
    expect(html, contains('<span>3 / 3</span>'));
    expect(html, contains('이달 상태: 긴급 관리 필요'));
    expect(html, contains('<b>3수조 폐사가 늘고 있고</b>'));
    expect(html, contains('10월 관리 권고'));
    // 3수조 DO 4.8·4.7은 기준(5) 밖 → 표에서 강조, 기록 요약에 횟수.
    expect('<td class="out">'.allMatches(html), hasLength(2));
    expect(html, contains('16회 측정 — 기준 밖 2회'));
    expect(html, contains('9/28 (월)'));
    expect(html, isNot(contains('**')));
  });

  test('예시가 없는 양식장은 해양환경·수조 쪽을 빼고 2쪽으로 나온다', () {
    final html = buildFarmReportHtml(FarmMonthlyReports.fallback(sinil, orgName: '해강수산질병관리원'));

    expect('class="page"'.allMatches(html), hasLength(2));
    expect(html, isNot(contains('해양환경 데이터')));
    expect(html, isNot(contains('이달 기록 요약')));
    expect(html, contains('문의'));
  });

  test('문장 속 HTML 특수문자는 이스케이프된다', () {
    final farm = sinil.copyWith(name: '<img src=x>');
    final html = buildFarmReportHtml(FarmMonthlyReports.fallback(farm, orgName: 'A&B'));

    expect(html, isNot(contains('<img src=x>')));
    expect(html, contains('<h1>&lt;img src=x&gt;</h1>'));
    expect(html, contains('A&amp;B'));
  });
}
