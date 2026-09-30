import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/risk_badge.dart';
import '../../data/repositories/share_link_repository.dart';

/// Public, unauthenticated `/r/:token` page — what a farm owner opens on
/// their own phone after the institute sends the share link.
class SharedReportWebScreen extends ConsumerWidget {
  const SharedReportWebScreen({super.key, required this.token});

  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FutureBuilder<SharedReportBundle?>(
          future: ref.read(shareLinkRepositoryProvider).resolveToken(token),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final bundle = snapshot.data;
            if (bundle == null) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('링크가 만료되었거나 존재하지 않습니다.', style: TextStyle(color: AppColors.textMuted)),
                ),
              );
            }

            final farm = bundle.farm;
            final report = bundle.report;

            return Column(
              children: [
                Container(
                  color: const Color(0xFFE7ECF2),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline, size: 11, color: AppColors.neutralIcon),
                      const SizedBox(width: 6),
                      Text('${Uri.base.host}/r/$token', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF5B6B80))),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                  decoration: const BoxDecoration(color: AppColors.surface, border: Border(bottom: BorderSide(color: AppColors.border))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('AquaConnect', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.brandDark)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(20)),
                        child: const Text('공유된 리포트', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.neutralIcon)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    children: [
                      Text(farm.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(
                          [
                            farm.address,
                            if (bundle.organizationName?.isNotEmpty ?? false) '${bundle.organizationName} 제공',
                            '${report.periodLabel} 리포트',
                          ].join(' · '),
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textTertiary)),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(color: const Color(0xFFF0DCCF)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                RiskBadge(level: report.riskLevel),
                                const SizedBox(width: 10),
                                Expanded(child: Text(report.headline, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(report.summary, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.5)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(color: AppColors.brandTintStrong, border: Border.all(color: AppColors.brandTintBorder), borderRadius: BorderRadius.circular(14)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('AI 정리 소견', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.brandDark)),
                            const SizedBox(height: 8),
                            for (final finding in report.findings)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('•  ', style: TextStyle(fontSize: 12, color: AppColors.brandInk)),
                                    Expanded(
                                      child: Text(finding, style: const TextStyle(fontSize: 12, color: AppColors.brandInk, height: 1.5)),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 2),
                            const Divider(height: 1, color: AppColors.brandTintBorder),
                            const SizedBox(height: 8),
                            const Text(
                              'AI는 기록·이미지·환경 변화의 이상징후를 정리해 보여줍니다. 최종 진단과 처방은 수산질병관리원이 수행합니다.',
                              style: TextStyle(fontSize: 10, color: AppColors.brandInkFaint, fontStyle: FontStyle.italic, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('지금 확인해보세요 (후속 조치)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 10),
                            for (final action in report.followUps)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.check, size: 14, color: AppColors.good),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(action, style: const TextStyle(fontSize: 12.5, color: Color(0xFF3A4A5E), height: 1.5))),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 4),
                            PrimaryButton(
                              label: farm.assignedMemberName == null ? '담당 관리사에게 연락하기' : '담당 관리사 ${farm.assignedMemberName}에게 연락하기',
                              icon: Icons.call,
                              color: AppColors.goodTint,
                              foreground: AppColors.good,
                              onPressed: bundle.assignedMemberPhone?.isNotEmpty ?? false
                                  ? () => launchUrl(Uri.parse('tel:${bundle.assignedMemberPhone}'))
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '위 내용은 AI가 정리한 일반적인 참고 사항이며 진단·처방이 아닙니다. 정확한 확인은 담당 수산질병관리사와 상담하세요.',
                              style: TextStyle(fontSize: 9.5, color: Color(0xFF8FA0B5), height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lock_clock_outlined, size: 12, color: Color(0xFF8FA0B5)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              bundle.link.expiresAt == null
                                  ? '앱 설치 없이 보는 화면입니다.'
                                  : '앱 설치 없이 보는 화면이며, 이 링크는 ${DateFormat('yyyy-MM-dd').format(bundle.link.expiresAt!)}까지 열람할 수 있습니다.',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF8FA0B5)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
