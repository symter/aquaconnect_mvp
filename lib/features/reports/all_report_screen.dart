import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/data_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/ai_report.dart';
import '../../data/models/farm.dart';
import 'ai_report_list_screen.dart' show AiReportStatusChip, aiReportPeriodLabel;

/// 전체 리포트 — every farm with its reports. A farm opens its previous
/// reports (review, 수정, 공유). The server makes last month's draft for each
/// farm at the start of the month; those wait here as 검토 대기 until a
/// 관리원 확정s and sends them.
class AllReportScreen extends ConsumerWidget {
  const AllReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmsAsync = ref.watch(farmsProvider);
    final summaries = ref.watch(aiFarmSummariesProvider).valueOrNull ?? const <AiFarmReportSummary>[];
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
                          data: (farms) => Text('${session?.organization.name ?? ''} · 관리 양식장 ${farms.length}곳',
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
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(farmsProvider);
                  ref.invalidate(aiFarmSummariesProvider);
                },
                child: farmsAsync.when(
                  data: (farms) => _Body(farms: farms, summaries: {for (final s in summaries) s.farmId: s}),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.farms, required this.summaries});

  final List<Farm> farms;
  final Map<String, AiFarmReportSummary> summaries;

  @override
  Widget build(BuildContext context) {
    int pendingOf(Farm f) => summaries[f.id]?.pending ?? 0;
    final pending = farms.fold<int>(0, (n, f) => n + pendingOf(f));
    // 검토 대기가 있는 양식장 먼저, 그다음 이름순.
    final sorted = [...farms]
      ..sort((a, b) {
        final pa = pendingOf(a) > 0, pb = pendingOf(b) > 0;
        if (pa != pb) return pa ? -1 : 1;
        return a.name.compareTo(b.name);
      });

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        if (pending > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.warningTint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.rate_review_outlined, size: 18, color: AppColors.warningTintInk),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('검토 대기 리포트 $pending건',
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.warningTintInk)),
                      const SizedBox(height: 3),
                      const Text('지난달 리포트 초안이 자동으로 만들어졌어요. 양식장을 눌러 확인·수정한 뒤 어가에 보내 주세요. 보내기 전에는 어가에 보이지 않아요.',
                          style: TextStyle(fontSize: 11.5, color: AppColors.warningTintInk, height: 1.45)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => context.push('/ai-reports/agency'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(border: Border.all(color: AppColors.brandTintBorder), borderRadius: BorderRadius.circular(14)),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome, size: 18, color: AppColors.brand),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI 종합 리포트', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                        Text('관리 양식장 전체 메모를 기간별로 AI가 정리해요 (원장님 보고용)',
                            style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppColors.neutralArrow),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text('양식장별 리포트', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        const Text('양식장을 누르면 이전 리포트를 보고, 고치고, 어가에 공유할 수 있어요.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary)),
        const SizedBox(height: 10),
        if (farms.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('등록된 양식장이 없어요', style: TextStyle(fontSize: 12.5, color: AppColors.textMuted))),
          ),
        for (final farm in sorted) ...[
          _FarmReportRow(farm: farm, summary: summaries[farm.id]),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _FarmReportRow extends StatelessWidget {
  const _FarmReportRow({required this.farm, required this.summary});

  final Farm farm;
  final AiFarmReportSummary? summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final latest = s?.latest;
    final pending = s?.pending ?? 0;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/reports/${farm.id}/ai'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: pending > 0 ? AppColors.warning : AppColors.border, width: pending > 0 ? 1.5 : 1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(farm.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                        ),
                        if (pending > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.warningTint, borderRadius: BorderRadius.circular(20)),
                            child: Text('검토 대기 $pending',
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.warningTintInk)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (latest != null) ...[
                          AiReportStatusChip(report: latest),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            [
                              if (farm.region.isNotEmpty) farm.region,
                              if (latest == null) '리포트 없음' else '최근 ${aiReportPeriodLabel(latest)}',
                              if ((s?.total ?? 0) > 1) '총 ${s!.total}건',
                            ].join(' · '),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.neutralArrow),
            ],
          ),
        ),
      ),
    );
  }
}
