import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/data_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/farm_card.dart';
import '../../data/models/farm.dart';
import '../../data/models/monthly_report.dart';
import 'monthly_report_section.dart';

/// 홈 → 전체 리포트. 위는 관리원 내부용 월별 리포트, 아래는 양식장 목록이며
/// 양식장을 누르면 어가에게 전달되는 관리 리포트를 미리 본다.
class AllReportScreen extends ConsumerWidget {
  const AllReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmsAsync = ref.watch(farmsProvider);
    final session = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              decoration: const BoxDecoration(color: AppColors.surface, border: Border(bottom: BorderSide(color: AppColors.border))),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('전체 리포트', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                        farmsAsync.when(
                          data: (farms) => Text('${session?.organization.name ?? ''} · 담당 어가 ${farms.length}곳',
                              style: const TextStyle(fontSize: 11.5, color: AppColors.textTertiary)),
                          loading: () => const SizedBox.shrink(),
                          error: (_, _) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  const MonthlyReportSection(report: MonthlyReportExample.september2026),
                  const SizedBox(height: 24),
                  const Text('양식장별 관리 리포트',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  const Text('양식장을 누르면 수산질병관리원이 어가에게 전달하는 관리 리포트를 볼 수 있습니다.',
                      style: TextStyle(fontSize: 11.5, height: 1.4, color: AppColors.textTertiary)),
                  const SizedBox(height: 10),
                  farmsAsync.when(
                    data: (farms) => _FarmList(farms: farms),
                    loading: () => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Text('$e'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FarmList extends StatelessWidget {
  const _FarmList({required this.farms});

  final List<Farm> farms;

  @override
  Widget build(BuildContext context) {
    if (farms.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('담당 양식장이 없습니다.', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
      );
    }
    final sorted = [...farms]..sort((a, b) => a.riskLevel.index.compareTo(b.riskLevel.index));
    return Column(
      children: [
        for (final farm in sorted) ...[
          FarmCard(farm: farm, onTap: () => context.push('/reports/${farm.id}/farm-report')),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
