import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/data_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/farm_card.dart';
import '../../core/widgets/memo_composer.dart';
import '../../data/models/farm.dart';
import '../../data/models/risk_level.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  RiskLevel? _riskFilter;
  bool _mineOnly = true;

  @override
  Widget build(BuildContext context) {
    final farmsAsync = ref.watch(farmsProvider);
    final session = ref.watch(authStateProvider).valueOrNull;
    final orgName = session?.organization.name ?? 'AquaConnect';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFE3EFFA), AppColors.background],
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.notifications_none, size: 19, color: AppColors.neutralIconStrong),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'AquaConnect',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.brandDark),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        orgName,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.brand),
                      ),
                    ),
                    const SizedBox(height: 16),
                    farmsAsync.when(
                      data: (farms) => MemoComposer(
                        farms: farms,
                        compact: true,
                        onSubmit: ({required content, farm, tags = const []}) {
                          ref.read(memoRepositoryProvider).addMemo(
                                farmId: farm?.id,
                                farmName: farm?.name,
                                content: content,
                                tags: tags,
                              );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('메모가 저장되었습니다.')),
                          );
                        },
                      ),
                      loading: () => const SizedBox(height: 44),
                      error: (e, _) => Text('$e'),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () => context.push('/memo'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            farmsAsync.when(
                              data: (farms) => Row(
                                children: [
                                  Text('${farms.length}',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.brand)),
                                  const SizedBox(width: 6),
                                  const Text('담당 어가 · 메모 보러가기',
                                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                ],
                              ),
                              loading: () => const SizedBox.shrink(),
                              error: (_, _) => const SizedBox.shrink(),
                            ),
                            Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: const Icon(Icons.chevron_right, size: 14, color: AppColors.brand),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _ReportStatusCard(),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('담당 양식장들', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      Text('위험도순', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.brand)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  farmsAsync.when(
                    data: (farms) => _FarmFilterRow(
                      farms: farms,
                      mineOnly: _mineOnly,
                      riskFilter: _riskFilter,
                      onMineOnly: () => setState(() {
                        _mineOnly = true;
                        _riskFilter = null;
                      }),
                      onAll: () => setState(() {
                        _mineOnly = false;
                        _riskFilter = null;
                      }),
                      onRisk: (r) => setState(() => _riskFilter = r),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 10),
                  farmsAsync.when(
                    data: (farms) {
                      final filtered = farms.where((f) => _riskFilter == null || f.riskLevel == _riskFilter).toList();
                      return Column(
                        children: [
                          for (final farm in filtered) ...[
                            FarmCard(farm: farm, onTap: () => context.push('/reports/${farm.id}/farm-report')),
                            const SizedBox(height: 10),
                          ],
                        ],
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Text('불러오기 실패: $e'),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FarmFilterRow extends StatelessWidget {
  const _FarmFilterRow({
    required this.farms,
    required this.mineOnly,
    required this.riskFilter,
    required this.onMineOnly,
    required this.onAll,
    required this.onRisk,
  });

  final List<Farm> farms;
  final bool mineOnly;
  final RiskLevel? riskFilter;
  final VoidCallback onMineOnly;
  final VoidCallback onAll;
  final void Function(RiskLevel?) onRisk;

  int _count(RiskLevel level) => farms.where((f) => f.riskLevel == level).length;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          FilterPillChip(label: '내 담당 ${farms.length}', selected: mineOnly, onTap: onMineOnly),
          const SizedBox(width: 6),
          FilterPillChip(label: '전체 ${farms.length}', selected: !mineOnly, onTap: onAll),
          const SizedBox(width: 6),
          FilterPillChip(
            label: '위험 ${_count(RiskLevel.danger)}',
            selected: riskFilter == RiskLevel.danger,
            onTap: () => onRisk(riskFilter == RiskLevel.danger ? null : RiskLevel.danger),
            selectedColor: AppColors.dangerTint,
            selectedTextColor: AppColors.danger,
          ),
          const SizedBox(width: 6),
          FilterPillChip(
            label: '주의 ${_count(RiskLevel.warning)}',
            selected: riskFilter == RiskLevel.warning,
            onTap: () => onRisk(riskFilter == RiskLevel.warning ? null : RiskLevel.warning),
            selectedColor: AppColors.warningTint,
            selectedTextColor: AppColors.warningDark,
          ),
          const SizedBox(width: 6),
          FilterPillChip(
            label: '양호 ${_count(RiskLevel.good)}',
            selected: riskFilter == RiskLevel.good,
            onTap: () => onRisk(riskFilter == RiskLevel.good ? null : RiskLevel.good),
            selectedColor: AppColors.goodTint,
            selectedTextColor: AppColors.good,
          ),
        ],
      ),
    );
  }
}

class _ReportStatusCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmsAsync = ref.watch(farmsProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('리포트 현황', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: const [
              SourceBadgeChip(
                icon: Icons.water,
                label: '해양환경 데이터',
                bg: AppColors.brandTint,
                fg: AppColors.brand,
              ),
              SourceBadgeChip(
                icon: Icons.description_outlined,
                label: '현장 메모',
                bg: AppColors.goodTint,
                fg: AppColors.good,
              ),
            ],
          ),
          const SizedBox(height: 12),
          farmsAsync.when(
            data: (farms) {
              final risky = farms.where((f) => f.riskLevel == RiskLevel.danger).toList();
              if (risky.isEmpty) {
                return const SizedBox.shrink();
              }
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: AppColors.dangerTint, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(color: AppColors.dangerTintStrong, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.dangerDark),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('고수온 영향 위험 양식장 ${risky.length}곳 확인',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.dangerDark)),
                          const SizedBox(height: 2),
                          const Text('아래 목록에서 확인하세요',
                              style: TextStyle(fontSize: 12, color: AppColors.dangerInk)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => GoRouter.of(context).push('/reports'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.chevron_right, size: 16),
              label: const Text('전체 리포트 보기', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}
