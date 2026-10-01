import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/onboarding_provider.dart';
import '../theme/app_colors.dart';
import 'responsive_mobile_frame.dart';
import 'tutorial_overlay.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _tabs = [
    (icon: Icons.home_outlined, activeIcon: Icons.home, label: '홈'),
    (icon: Icons.edit_note_outlined, activeIcon: Icons.edit_note, label: '메모'),
    (icon: Icons.info_outline, activeIcon: Icons.info, label: '정보'),
    (icon: Icons.person_outline, activeIcon: Icons.person, label: '마이페이지'),
  ];

  /// One-time intro shown the first time each tab is opened (after the
  /// welcome card). Same order as [_tabs].
  static const _intros = [
    (id: 'home', title: '홈', body: '담당 양식장을 위험도순으로 확인하고, 위쪽 입력창에서 바로 메모를 남길 수 있어요.'),
    (id: 'memo', title: '메모', body: "양식장별 메모를 모아 보고, '할일' 탭에서 해야 할 일을 관리해요."),
    (id: 'info', title: '정보', body: '수산질병 정보와 바다 수온을 확인해요. 필터는 여러 개를 함께 선택할 수 있어요.'),
    (id: 'mypage', title: '마이페이지', body: '양식장·구성원 관리, 바다 위치, 하루 요약 설정은 여기에서 해요.'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarding = ref.watch(onboardingProvider).valueOrNull;
    final notifier = ref.read(onboardingProvider.notifier);
    final intro = _intros[navigationShell.currentIndex];

    Widget? overlay;
    if (onboarding != null && !onboarding.welcomeSeen) {
      overlay = TutorialOverlay(
        icon: Icons.waves,
        title: 'AquaConnect에 오신 걸 환영해요',
        body: '담당 양식장의 수온·질병 위험을 한눈에 확인하고, 리포트를 어가에 바로 공유해 보세요.',
        primaryLabel: '시작하기',
        onPrimary: notifier.markWelcomeSeen,
        onSkip: () async {
          for (final i in _intros) {
            await notifier.markCoachmarkSeen(i.id);
          }
          await notifier.markWelcomeSeen();
        },
      );
    } else if (onboarding != null && !onboarding.coachmarksSeen.contains(intro.id)) {
      overlay = TutorialOverlay(
        icon: _tabs[navigationShell.currentIndex].activeIcon,
        title: intro.title,
        body: intro.body,
        primaryLabel: '확인',
        onPrimary: () => notifier.markCoachmarkSeen(intro.id),
        pointsDown: true,
      );
    }

    return ResponsiveMobileFrame(
      child: Scaffold(
        body: Stack(children: [navigationShell, ?overlay]),
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 9, bottom: 4),
              child: Row(
                children: List.generate(_tabs.length, (i) {
                  final tab = _tabs[i];
                  final selected = i == navigationShell.currentIndex;
                  final color = selected ? AppColors.brand : AppColors.textMuted;
                  return Expanded(
                    child: InkWell(
                      onTap: () => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(selected ? tab.activeIcon : tab.icon, size: 21, color: color),
                          const SizedBox(height: 4),
                          Text(
                            tab.label,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
