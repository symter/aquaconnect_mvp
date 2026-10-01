import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/onboarding_provider.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/member.dart';
import '../mypage/ocean_station_picker_sheet.dart';

class _Step {
  const _Step(this.id, this.label, this.icon, {this.ownerOnly = false});
  final String id;
  final String label;
  final IconData icon;

  /// Hidden from 직원 accounts, who can't register farms or invite members.
  final bool ownerOnly;
}

const _steps = [
  _Step('farm', '양식장 등록하기', Icons.home_work_outlined, ownerOnly: true),
  _Step('station', '바다 위치(수온 관측소) 선택하기', Icons.water_outlined),
  _Step('members', '구성원 초대하기', Icons.groups_outlined, ownerOnly: true),
  _Step('memo', '첫 메모 남기기', Icons.edit_note),
  _Step('share', '리포트 공유하기', Icons.link),
];

/// Home "시작 가이드" checklist. Steps are checked off when tapped (they jump
/// to the relevant screen) — completion can't be derived from data because
/// members/share links aren't backed by real state yet.
class OnboardingChecklistCard extends ConsumerWidget {
  const OnboardingChecklistCard({super.key});

  void _open(BuildContext context, WidgetRef ref, _Step step) {
    ref.read(onboardingProvider.notifier).completeStep(step.id);
    switch (step.id) {
      case 'farm':
        context.push('/mypage/farms');
      case 'station':
        showOceanStationPickerSheet(context);
      case 'members':
        context.push('/mypage/members');
      case 'memo':
        context.go('/memo');
      case 'share':
        context.push('/reports');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarding = ref.watch(onboardingProvider).valueOrNull;
    if (onboarding == null || onboarding.checklistHidden) return const SizedBox.shrink();

    final isEmployee = ref.watch(authStateProvider).valueOrNull?.member.role == MemberRole.employee;
    final steps = _steps.where((s) => !(isEmployee && s.ownerOnly)).toList();
    final doneCount = steps.where((s) => onboarding.checklistDone.contains(s.id)).length;
    if (doneCount == steps.length) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.brandTint,
        border: Border.all(color: AppColors.brandTintBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('시작 가이드',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.brandDark)),
              ),
              Text('$doneCount/${steps.length}',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.brand)),
              IconButton(
                tooltip: '닫기',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                onPressed: () => ref.read(onboardingProvider.notifier).hideChecklist(),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: doneCount / steps.length,
                minHeight: 5,
                backgroundColor: Colors.white,
                color: AppColors.brand,
              ),
            ),
          ),
          for (final step in steps)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _open(context, ref, step),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
                child: Row(
                  children: [
                    Icon(
                      onboarding.checklistDone.contains(step.id) ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 20,
                      color: onboarding.checklistDone.contains(step.id) ? AppColors.brand : AppColors.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        step.label,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: onboarding.checklistDone.contains(step.id) ? AppColors.textMuted : AppColors.textPrimary,
                          decoration: onboarding.checklistDone.contains(step.id) ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 16, color: AppColors.neutralArrow),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
