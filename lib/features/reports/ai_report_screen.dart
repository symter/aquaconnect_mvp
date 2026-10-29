import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers/data_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/buttons.dart';
import '../../data/models/ai_report.dart';
import 'ai_report_document.dart';
import 'ai_report_list_screen.dart';
import 'share_link_sheet.dart';

/// One AI 리포트: the form ([AiReportDocument]), the evidence-check warnings,
/// the memos it was built from, and its lifecycle — 수정 (섹션별) → 확정
/// (= 판 저장) → 발송 to the farm's share link → 새 판 만들기 to fix a sent one.
class AiReportScreen extends ConsumerStatefulWidget {
  const AiReportScreen({super.key, required this.reportId});

  final String reportId;

  @override
  ConsumerState<AiReportScreen> createState() => _AiReportScreenState();
}

class _AiReportScreenState extends ConsumerState<AiReportScreen> {
  bool _busy = false;

  void _refresh(AiReport r) {
    ref.invalidate(aiReportProvider(r.id));
    ref.invalidate(aiReportVersionsProvider(r.id));
    if (r.isAgency) {
      ref.invalidate(aiAgencyReportsProvider);
    } else {
      ref.invalidate(aiReportsProvider(r.farmId!));
    }
  }

  Future<T?> _run<T>(Future<T> Function() action, String done, AiReport r) async {
    setState(() => _busy = true);
    try {
      final out = await action();
      _refresh(r);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
      return out;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('처리하지 못했어요: $e')));
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _ask(String title, String body, String ok, {bool danger = false}) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(ok, style: danger ? const TextStyle(color: AppColors.danger) : null),
          ),
        ],
      ),
    );
    return res == true;
  }

  Future<void> _edit(AiReport r) async {
    final edited = await Navigator.of(context).push<String>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => AiSectionEditor(report: r)),
    );
    if (edited == null || edited.trim() == (r.body ?? '').trim()) return;
    await _run(() => ref.read(aiReportRepositoryProvider).updateBody(r.id, edited), '수정 내용을 저장했어요.', r);
  }

  Future<void> _editOpinion(AiReport r) async {
    final edited = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _TextEditor(
          initial: r.finalOpinion,
          title: '전문가 최종 의견',
          hint: '양식장에 전할 최종 의견을 적어 주세요. 확정하면 리포트 끝에 함께 나갑니다.',
        ),
      ),
    );
    if (edited == null || edited.trim() == r.finalOpinion.trim()) return;
    await _run(() => ref.read(aiReportRepositoryProvider).updateFinalOpinion(r.id, edited.trim()), '최종 의견을 저장했어요.', r);
  }

  Future<void> _confirm(AiReport r) async {
    if (r.checkCount > 0 &&
        !await _ask('확인 필요 항목이 있어요', '근거 검증에서 걸린 문장 ${r.checkCount}개가 있습니다. 검토를 마쳤다면 확정해 주세요.', '확정하기')) {
      return;
    }
    await _run(() => ref.read(aiReportRepositoryProvider).setConfirmed(r.id, confirmed: true), '확정했어요 · 제${r.version + 1}판', r);
  }

  Future<void> _send(AiReport r) async {
    final farm = ref.read(farmByIdProvider(r.farmId!)).valueOrNull;
    if (!await _ask('양식장에 발송할까요?', '${farm?.name ?? '양식장'}의 공유 링크에서 이 리포트(제${r.version}판)를 볼 수 있게 됩니다. 발송한 뒤 고치려면 새 판을 만들어야 해요.', '발송')) {
      return;
    }
    final out = await _run(() => ref.read(aiReportRepositoryProvider).send(r.id), '발송했어요. 링크를 양식장에 보내 주세요.', r);
    if (out != null && farm != null && mounted) showShareLinkSheet(context, farm: farm);
  }

  Future<void> _revise(AiReport r) async {
    if (!await _ask('새 판을 만들까요?', '초안으로 돌아가 고칠 수 있어요. 양식장은 다시 발송할 때까지 지금 발송본(제${r.version}판)을 봅니다.', '새 판 만들기')) return;
    await _run(() => ref.read(aiReportRepositoryProvider).revise(r.id), '새 판을 만들었어요. 고친 뒤 다시 확정·발송해 주세요.', r);
  }

  Future<void> _delete(AiReport r) async {
    final body = r.isSent || r.sentAt != null ? '양식장에 발송한 리포트도 함께 사라져요. 삭제하면 되돌릴 수 없어요.' : '삭제하면 되돌릴 수 없어요.';
    if (!await _ask('AI 리포트를 삭제할까요?', body, '삭제', danger: true)) return;
    try {
      await ref.read(aiReportRepositoryProvider).delete(r.id);
      _refresh(r);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제하지 못했어요: $e')));
    }
  }

  void _showEvidence(AiReport r, String section, String line) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => AiEvidenceSheet(report: r, section: section, line: line),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(aiReportProvider(widget.reportId));
    final r = reportAsync.valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.brandDark,
        title: Text(r?.isAgency == true ? 'AI 종합 리포트' : 'AI 관리 리포트',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.brandDark)),
        actions: [
          if (r != null) ...[
            IconButton(
              tooltip: '인쇄 / PDF',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: () => context.push('/ai-reports/${r.id}/print'),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                switch (v) {
                  case 'evidence':
                    _showEvidence(r, '', '');
                  case 'versions':
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: AppColors.surface,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                      builder: (_) => _VersionsSheet(report: r),
                    );
                  case 'copy':
                    Clipboard.setData(ClipboardData(text: r.body ?? ''));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('리포트 내용을 복사했어요.')));
                  case 'delete':
                    _delete(r);
                }
              },
              itemBuilder: (_) => [
                if (!r.isAgency) const PopupMenuItem(value: 'evidence', child: Text('근거 확인')),
                const PopupMenuItem(value: 'versions', child: Text('판 기록')),
                const PopupMenuItem(value: 'copy', child: Text('내용 복사')),
                const PopupMenuItem(value: 'delete', child: Text('삭제', style: TextStyle(color: AppColors.danger))),
              ],
            ),
          ],
        ],
      ),
      body: reportAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('리포트를 불러오지 못했어요.\n$e', textAlign: TextAlign.center)),
        data: (r) => Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  _MetaCard(report: r),
                  if (r.checks.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _ChecksCard(checks: r.checks),
                  ],
                  if (!r.isAgency && r.evidence.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('문장을 누르면 그 문장의 근거 메모를 볼 수 있어요.',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                  const SizedBox(height: 8),
                  AiReportDocument(
                    report: r,
                    farmName: r.farmId == null ? '' : ref.watch(farmByIdProvider(r.farmId!)).valueOrNull?.name ?? '',
                    orgName: ref.watch(authStateProvider).valueOrNull?.organization.name ?? '',
                    onEditOpinion: _busy || !r.isDraft ? null : () => _editOpinion(r),
                    onItemTap: r.isAgency ? null : (section, line) => _showEvidence(r, section, line),
                  ),
                  const SizedBox(height: 12),
                  _SourceMemosCard(memos: r.memos.where((m) => m.period == 'current').toList()),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
              child: switch (r.status) {
                'draft' => Row(
                    children: [
                      Expanded(child: OutlineButton(label: '수정', onPressed: _busy ? null : () => _edit(r))),
                      const SizedBox(width: 10),
                      Expanded(child: PrimaryButton(label: '확정', onPressed: _busy ? null : () => _confirm(r))),
                    ],
                  ),
                'confirmed' => Row(
                    children: [
                      Expanded(
                        child: OutlineButton(
                          label: '확정 취소',
                          onPressed: _busy
                              ? null
                              : () => _run(() => ref.read(aiReportRepositoryProvider).setConfirmed(r.id, confirmed: false), '확정을 취소했어요.', r),
                        ),
                      ),
                      if (!r.isAgency) ...[
                        const SizedBox(width: 10),
                        Expanded(child: PrimaryButton(label: '양식장에 발송', icon: Icons.send, onPressed: _busy ? null : () => _send(r))),
                      ],
                    ],
                  ),
                _ => Row(
                    children: [
                      Expanded(child: OutlineButton(label: '새 판 만들기', onPressed: _busy ? null : () => _revise(r))),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PrimaryButton(
                          label: '링크 다시 보내기',
                          icon: Icons.link,
                          onPressed: () {
                            final farm = ref.read(farmByIdProvider(r.farmId!)).valueOrNull;
                            if (farm != null) showShareLinkSheet(context, farm: farm);
                          },
                        ),
                      ),
                    ],
                  ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaCard extends ConsumerWidget {
  const _MetaCard({required this.report});
  final AiReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = report;
    final farm = r.farmId == null ? null : ref.watch(farmByIdProvider(r.farmId!)).valueOrNull;
    final fmt = DateFormat('M/d HH:mm');
    final stages = ((r.staged?['stages'] as List<dynamic>?) ?? []).length;
    final lines = <String>[
      'AI 작성 · ${r.model} · ${r.createdByName.isEmpty ? '' : '${r.createdByName} · '}${fmt.format(r.createdAt.toLocal())}',
      if (stages > 0) '메모가 많아 $stages개 묶음으로 먼저 정리한 뒤 썼어요',
      if (r.examples.isNotEmpty) '승인된 이전 리포트 ${r.examples.length}건을 문체 참고 예시로 썼어요',
      if (r.editedAt != null) '전문가 수정 · ${r.editedByName ?? ''} · ${fmt.format(r.editedAt!.toLocal())}',
      if (r.confirmedAt != null) '확정 · ${r.confirmedByName ?? ''} · ${fmt.format(r.confirmedAt!.toLocal())} · 제${r.version}판',
      if (r.sentAt != null) '${r.isSent ? '발송' : '마지막 발송'} · ${r.sentByName ?? ''} · ${fmt.format(r.sentAt!.toLocal())}',
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AiReportStatusChip(report: r),
              const SizedBox(width: 8),
              Expanded(
                child: Text(r.isAgency ? '관리원 종합 리포트' : farm?.name ?? '',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('${aiReportPeriodLabel(r)} · 메모 ${r.memoCount}건${r.commentCount > 0 ? ' · 댓글 ${r.commentCount}개' : ''}',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          for (final l in lines) Text(l, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary, height: 1.5)),
          if (r.isDraft) ...[
            const SizedBox(height: 8),
            Text(
              r.sentAt != null
                  ? '새 판을 고치는 중이에요. 양식장은 다시 발송할 때까지 제${r.version}판을 봅니다.'
                  : 'AI 초안입니다. 메모에 없는 내용이 없는지 검토한 뒤 확정해 주세요.',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.warningInk),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChecksCard extends StatelessWidget {
  const _ChecksCard({required this.checks});
  final List<AiReportCheck> checks;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.warningTint,
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          leading: const Icon(Icons.warning_amber_rounded, color: AppColors.warningDark, size: 20),
          title: Text('확인 필요 ${checks.length}개',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.warningTintInk)),
          subtitle: const Text('근거 검증에서 걸린 문장이에요. 메모와 대조해 주세요.',
              style: TextStyle(fontSize: 11, color: AppColors.warningTintInk)),
          children: [
            for (final c in checks)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.section, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.warningInk)),
                    Text(c.text, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.45)),
                    Text('→ ${c.problem}', style: const TextStyle(fontSize: 11, color: AppColors.dangerDark, height: 1.45)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SourceMemosCard extends StatelessWidget {
  const _SourceMemosCard({required this.memos});
  final List<AiReportMemo> memos;

  @override
  Widget build(BuildContext context) {
    if (memos.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          title: Text('근거 메모 ${memos.length}건',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          subtitle: const Text('리포트를 만들 때 AI에 보낸 그대로예요', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
          children: [for (final m in memos) _MemoQuote(memo: m)],
        ),
      ),
    );
  }
}

class _MemoQuote extends StatelessWidget {
  const _MemoQuote({required this.memo});
  final AiReportMemo memo;

  @override
  Widget build(BuildContext context) {
    final m = memo;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              if (m.farmName != null) m.farmName!,
              m.date,
              m.kind,
              m.author,
              if (m.period == 'previous') '이전 기간',
            ].where((s) => s.isNotEmpty).join(' · '),
            style: const TextStyle(fontSize: 10.5, color: AppColors.textTertiary),
          ),
          Text(m.body, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.45)),
        ],
      ),
    );
  }
}

/// 근거 확인. With a [line], the memos and comments behind that one item;
/// without one (menu → 근거 확인), every AI item with its 근거.
class AiEvidenceSheet extends StatelessWidget {
  const AiEvidenceSheet({super.key, required this.report, required this.section, required this.line});

  final AiReport report;
  final String section;
  final String line;

  @override
  Widget build(BuildContext context) {
    final r = report;
    final all = line.isEmpty;
    final match = all
        ? null
        : r.evidence.where((s) => s.title == section).expand((s) => s.items).where((it) => it.line.trim() == line.trim()).firstOrNull;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          children: [
            Text(all ? '근거 확인' : '이 문장의 근거',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text('리포트를 만들 때 AI에 보낸 메모 원문이에요.', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
            const SizedBox(height: 14),
            if (all)
              for (final s in r.evidence) ...[
                Text(s.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.brand)),
                const SizedBox(height: 6),
                for (final it in s.items) _EvidenceItem(report: r, item: it),
                const SizedBox(height: 10),
              ]
            else if (match != null)
              _EvidenceItem(report: r, item: match)
            else ...[
              Text(line.replaceFirst(RegExp(r'^- '), ''), style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary, height: 1.5)),
              const SizedBox(height: 8),
              const Text('전문가가 고치거나 새로 쓴 문장이라 자동으로 연결된 근거가 없어요. 메뉴 → 근거 확인에서 AI 초안의 근거를 볼 수 있어요.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.warningInk, height: 1.45)),
            ],
          ],
        ),
      ),
    );
  }
}

class _EvidenceItem extends StatelessWidget {
  const _EvidenceItem({required this.report, required this.item});
  final AiReport report;
  final AiEvidenceItem item;

  @override
  Widget build(BuildContext context) {
    final memos = item.evidence.map(report.memoNumbered).whereType<AiReportMemo>().toList();
    final comments = item.commentRefs.map((k) => report.comments.where((c) => c.key == k).firstOrNull).whereType<AiReportComment>().toList();
    final text = item.line.replaceFirst(RegExp(r'^- '), '').replaceAll(RegExp(r'\s*〔근거[^〕]*〕'), '');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(color: AppColors.neutralCard, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.5)),
          const SizedBox(height: 8),
          if (memos.isEmpty && comments.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('근거 메모가 없는 문장이에요(안내·제안·공공데이터).', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ),
          for (final m in memos) _MemoQuote(memo: m),
          for (final c in comments)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('댓글 · ${c.date} · ${c.author}${c.late ? ' · 기간 이후 추가 기록' : ''}',
                      style: const TextStyle(fontSize: 10.5, color: AppColors.textTertiary)),
                  Text(c.body, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.45)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _VersionsSheet extends ConsumerWidget {
  const _VersionsSheet({required this.report});
  final AiReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionsAsync = ref.watch(aiReportVersionsProvider(report.id));
    final fmt = DateFormat('yyyy.M.d HH:mm');
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          children: [
            const Text('판 기록', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text('확정할 때마다 그 시점 내용이 한 판으로 남아요. 이전 판은 지워지지 않아요.',
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
            const SizedBox(height: 14),
            versionsAsync.when(
              loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Text('불러오지 못했어요: $e'),
              data: (versions) => versions.isEmpty
                  ? const Text('아직 확정한 판이 없어요.', style: TextStyle(fontSize: 12.5, color: AppColors.textMuted))
                  : Column(
                      children: [
                        for (final v in versions)
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)),
                            child: Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                                childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                                title: Text('제${v.version}판 · ${v.approvedByName}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                                subtitle: Text(
                                  [
                                    '승인 ${fmt.format(v.approvedAt.toLocal())}',
                                    if (v.sends.isNotEmpty) '발송 ${v.sends.map((s) => fmt.format(s.sentAt.toLocal())).join(', ')}',
                                    v.editedSections.isEmpty ? 'AI 초안 그대로' : '수정: ${v.editedSections.join(', ')}',
                                  ].join('\n'),
                                  style: const TextStyle(fontSize: 11, color: AppColors.textTertiary, height: 1.45),
                                ),
                                children: [
                                  Text(v.body, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.5)),
                                  if (v.finalOpinion.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text('전문가 최종 의견: ${v.finalOpinion}',
                                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                  ],
                                ],
                              ),
                            ),
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

/// 섹션별 편집 (symterAI ReportEditor): one box per section with an 전문가
/// 수정 mark and 'AI 원본으로 되돌리기', or the whole text at once.
/// Pops the joined body, or null when cancelled.
class AiSectionEditor extends StatefulWidget {
  const AiSectionEditor({super.key, required this.report});
  final AiReport report;

  @override
  State<AiSectionEditor> createState() => _AiSectionEditorState();
}

class _AiSectionEditorState extends State<AiSectionEditor> {
  late final List<AiReportSection> _sections = parseAiReportBody(widget.report.body ?? '');
  late final Map<String, String> _original = {
    for (final s in parseAiReportBody(widget.report.aiBody ?? '')) s.title: s.lines.join('\n'),
  };
  late final List<TextEditingController> _controllers = [
    for (final s in _sections) TextEditingController(text: s.lines.join('\n')),
  ];
  late final _whole = TextEditingController(text: widget.report.body ?? '');
  bool _raw = false;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    _whole.dispose();
    super.dispose();
  }

  String _joined() => [
        for (final (i, s) in _sections.indexed)
          '## ${s.title}\n${_controllers[i].text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).join('\n')}',
      ].join('\n\n');

  void _switchMode(bool raw) {
    if (raw == _raw) return;
    setState(() {
      if (raw) {
        _whole.text = _joined();
      } else {
        final parsed = parseAiReportBody(_whole.text);
        _sections
          ..clear()
          ..addAll(parsed);
        for (final c in _controllers) {
          c.dispose();
        }
        _controllers
          ..clear()
          ..addAll([for (final s in parsed) TextEditingController(text: s.lines.join('\n'))]);
      }
      _raw = raw;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.brandDark,
        title: const Text('리포트 수정', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.brandDark)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_raw ? _whole.text : _joined()),
            child: const Text('저장', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.brand)),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('섹션별 편집')),
                ButtonSegment(value: true, label: Text('전체 텍스트')),
              ],
              selected: {_raw},
              onSelectionChanged: (v) => _switchMode(v.first),
              showSelectedIcon: false,
            ),
          ),
          Expanded(
            child: _raw
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: TextField(
                      controller: _whole,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(fontSize: 13, height: 1.55, color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        helperText: '"## 제목"은 섹션, "- "로 시작하는 줄은 항목이에요. AI 원문은 따로 보관됩니다.',
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      const Text('항목은 "- "로 시작하는 한 줄씩이에요. AI 원문은 따로 보관돼서 언제든 되돌릴 수 있어요.',
                          style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                      const SizedBox(height: 10),
                      for (final (i, s) in _sections.indexed)
                        ListenableBuilder(
                          listenable: _controllers[i],
                          builder: (context, _) {
                            final original = _original[s.title];
                            final current = _controllers[i].text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).join('\n');
                            final changed = original != null && current != original;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                border: Border.all(color: changed ? AppColors.brandTintBorder : AppColors.border),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(s.title,
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.brand)),
                                      ),
                                      if (changed) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: AppColors.brandTint, borderRadius: BorderRadius.circular(6)),
                                          child: const Text('전문가 수정',
                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.brand)),
                                        ),
                                        TextButton(
                                          onPressed: () => _controllers[i].text = original,
                                          child: const Text('AI 원본으로', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  TextField(
                                    controller: _controllers[i],
                                    maxLines: null,
                                    minLines: 3,
                                    style: const TextStyle(fontSize: 12.5, height: 1.55, color: AppColors.textPrimary),
                                    decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _TextEditor extends StatefulWidget {
  const _TextEditor({required this.initial, required this.title, required this.hint});
  final String initial;
  final String title;
  final String hint;

  @override
  State<_TextEditor> createState() => _TextEditorState();
}

class _TextEditorState extends State<_TextEditor> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.brandDark,
        title: Text(widget.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.brandDark)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_controller.text),
            child: const Text('저장', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.brand)),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.neutralCard,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(widget.hint, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                maxLength: 3000,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(fontSize: 13, height: 1.55, color: AppColors.textPrimary),
                decoration: const InputDecoration(border: InputBorder.none),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
