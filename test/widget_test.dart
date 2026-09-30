import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aquaconnect_mvp/app.dart';
import 'package:aquaconnect_mvp/core/providers/repository_providers.dart';
import 'package:aquaconnect_mvp/data/repositories/mock/mock_auth_repository.dart';
import 'package:aquaconnect_mvp/features/mypage/member_management_screen.dart';

void main() {
  testWidgets('App boots to the login screen when signed out', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AquaConnectApp()));
    await tester.pumpAndSettle();

    expect(find.text('AquaConnect'), findsWidgets);
    expect(find.text('로그인'), findsWidgets);
  });

  testWidgets('구성원 관리 화면은 가짜 구성원 없이 시작한다', (WidgetTester tester) async {
    final auth = MockAuthRepository();
    await tester.runAsync(() => auth.signIn(email: 'a', password: 'b'));
    await tester.pumpWidget(ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
      child: const MaterialApp(home: MemberManagementScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('아직 함께하는 구성원이 없어요'), findsOneWidget);
    expect(find.text('이원장'), findsNothing);
  });
}
