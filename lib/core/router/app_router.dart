import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/info/info_screen.dart';
import '../../features/memo/memo_screen.dart';
import '../../features/mypage/farm_management_screen.dart';
import '../../features/mypage/invite_accept_screen.dart';
import '../../features/mypage/member_management_screen.dart';
import '../../features/mypage/mypage_screen.dart';
import '../../features/reports/all_report_screen.dart';
import '../../features/reports/report_detail_screen.dart';
import '../../features/reports/shared_report_web_screen.dart';
import '../providers/repository_providers.dart';
import '../widgets/app_shell.dart';

/// Re-runs GoRouter's redirect logic whenever the auth stream emits, without
/// rebuilding the router itself (which would otherwise drop navigation state).
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final refreshStream = GoRouterRefreshStream(authRepository.authStateChanges());
  ref.onDispose(refreshStream.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshStream,
    redirect: (context, state) {
      final loggedIn = authRepository.currentSession != null;
      final path = state.matchedLocation;

      final isPublic = path == '/login' || path.startsWith('/r/');
      if (!loggedIn && !isPublic) return '/login';
      if (loggedIn && path == '/login') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/r/:token',
        builder: (context, state) => SharedReportWebScreen(token: state.pathParameters['token']!),
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const AllReportScreen(),
      ),
      GoRoute(
        path: '/reports/:farmId',
        builder: (context, state) => ReportDetailScreen(farmId: state.pathParameters['farmId']!),
      ),
      GoRoute(
        path: '/mypage/farms',
        builder: (context, state) => const FarmManagementScreen(),
      ),
      GoRoute(
        path: '/mypage/members',
        builder: (context, state) => const MemberManagementScreen(),
      ),
      GoRoute(
        path: '/mypage/invite-preview',
        builder: (context, state) => const InviteAcceptScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/', builder: (context, state) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/memo', builder: (context, state) => const MemoScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/info', builder: (context, state) => const InfoScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/mypage', builder: (context, state) => const MyPageScreen())]),
        ],
      ),
    ],
  );
});
