import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aquaconnect_mvp/app.dart';
import 'package:aquaconnect_mvp/features/mypage/member_management_screen.dart';

void main() {
  testWidgets('App boots to the login screen when signed out', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AquaConnectApp()));
    await tester.pumpAndSettle();

    expect(find.text('AquaConnect'), findsWidgets);
    expect(find.text('로그인'), findsWidgets);
  });

  testWidgets('구성원 관리 화면이 활성 구성원 목록을 렌더링한다', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: MemberManagementScreen()));
    await tester.pumpAndSettle();

    expect(find.text('구성원 4명'), findsOneWidget);
    expect(find.text('이동길'), findsOneWidget);
    expect(find.text('이원장'), findsOneWidget);
    expect(find.text('박관리'), findsOneWidget);
    expect(find.text('최관리'), findsOneWidget);
  });
}
