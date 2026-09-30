import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aquaconnect_mvp/data/models/monthly_report.dart';
import 'package:aquaconnect_mvp/features/reports/monthly_report_section.dart';

void main() {
  Future<void> pumpSection(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: MonthlyReportSection(report: MonthlyReportExample.september2026),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).first);
    await tester.tap(find.text(text).first);
    await tester.pumpAndSettle();
  }

  testWidgets('월별 리포트가 폰 폭에서 KPI·캘린더·현황판을 그린다', (tester) async {
    await pumpSection(tester);

    expect(find.text('수산질병관리원 월별 리포트'), findsOneWidget);
    expect(find.text('긴급 양식장'), findsOneWidget);
    expect(find.text('9월 업무 캘린더'), findsOneWidget);
    // 기준일(9/28) 패널이 기본으로 열린다: 예찰 1건 + DO·pH 3개 수조.
    expect(find.text('9/28 (월) · 4건'), findsOneWidget);
    expect(find.text('양식장 현황판'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('현황판 양식장을 누르면 9월 타임라인이 펼쳐진다', (tester) async {
    await pumpSection(tester);

    await tapText(tester, '진도 D');
    expect(find.textContaining('진도 D · 9월 진행 내용'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('메모 기록 탭을 모두 전환해도 레이아웃이 깨지지 않는다', (tester) async {
    await pumpSection(tester);

    for (final tab in ['검사', '바이러스 진단', '안전성 검사', '수조 DO·pH', '접종', '배달']) {
      await tapText(tester, tab);
      expect(tester.takeException(), isNull, reason: tab);
    }
  });

  testWidgets('캘린더에서 기록을 추가하면 그날 패널에 나타난다', (tester) async {
    await pumpSection(tester);

    await tapText(tester, '28일에 추가');
    await tester.enterText(find.widgetWithText(TextField, '내용'), '테스트 방문');
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();

    expect(find.text('9/28 (월) · 5건'), findsOneWidget);
    expect(find.textContaining('테스트 방문'), findsWidgets);
  });
}
