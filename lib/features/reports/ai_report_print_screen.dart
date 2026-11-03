import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/providers/data_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/ai_report.dart';
import 'ai_report_html.dart';
import 'farm_report_frame.dart';
import 'shared_report_tokens.dart';

/// 인쇄 / PDF로 저장 for staff: the report's A4 page ([buildAiReportHtml]) in
/// an iframe, and the browser's print dialog (where "PDF로 저장" keeps the
/// layout).
class AiReportPrintScreen extends ConsumerStatefulWidget {
  const AiReportPrintScreen({super.key, required this.reportId});

  final String reportId;

  @override
  ConsumerState<AiReportPrintScreen> createState() => _AiReportPrintScreenState();
}

class _AiReportPrintScreenState extends ConsumerState<AiReportPrintScreen> {
  final _frame = FarmReportFrameController();

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(aiReportProvider(widget.reportId));
    final r = reportAsync.valueOrNull;
    final farmName = r?.farmId == null ? '' : ref.watch(farmByIdProvider(r!.farmId!)).valueOrNull?.name ?? '';
    final orgName = ref.watch(authStateProvider).valueOrNull?.organization.name ?? '';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.brandDark,
        title: const Text('인쇄 / PDF', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.brandDark)),
        actions: [
          TextButton.icon(
            onPressed: r == null ? null : () => _frame.canPrint ? _frame.print() : null,
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('인쇄 / PDF로 저장', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: reportAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('리포트를 불러오지 못했어요.\n$e', textAlign: TextAlign.center)),
        data: (r) => Column(
          children: [
            if (r.isDraft)
              Container(
                width: double.infinity,
                color: AppColors.warningTint,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: const Text('초안이에요. 인쇄물에도 "초안" 표시가 남아요. 최종본은 확정한 뒤 인쇄해 주세요.',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.warningTintInk)),
              ),
            Expanded(child: FarmReportFrame(html: buildAiReportHtml(r, farmName: farmName, orgName: orgName), controller: _frame)),
          ],
        ),
      ),
    );
  }
}

/// What the farm opens from its share link: one AI 관리 리포트 it received
/// (`/r/:token/ai/:reportId`, no login), with PDF 저장.
class SharedAiReportScreen extends ConsumerStatefulWidget {
  const SharedAiReportScreen({super.key, required this.token, required this.reportId});

  final String token;
  final String reportId;

  @override
  ConsumerState<SharedAiReportScreen> createState() => _SharedAiReportScreenState();
}

class _SharedAiReportScreenState extends ConsumerState<SharedAiReportScreen> {
  late final Future<AiReport?> _future = ref.read(aiReportRepositoryProvider).getSent(widget.token, widget.reportId);
  final _frame = FarmReportFrameController();

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(textTheme: GoogleFonts.notoSansKrTextTheme(Theme.of(context).textTheme)),
      child: Scaffold(
        backgroundColor: SharedTokens.outerBg,
        body: FutureBuilder<AiReport?>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator(color: SharedTokens.primary));
            }
            final r = snapshot.data;
            if (r == null) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('리포트를 찾을 수 없거나 링크가 만료되었습니다.', style: TextStyle(color: SharedTokens.textSub)),
                ),
              );
            }
            return SafeArea(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    decoration: const BoxDecoration(color: SharedTokens.card, border: Border(bottom: BorderSide(color: SharedTokens.line))),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: '뒤로가기',
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: SharedTokens.text),
                          onPressed: () => context.canPop() ? context.pop() : context.go('/r/${widget.token}'),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text('AI 관리 리포트 · 제${r.version}판',
                                  style: const TextStyle(fontSize: 11, color: SharedTokens.textSub, fontWeight: FontWeight.w500)),
                              Text(r.farmName ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: SharedTokens.text)),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'PDF 저장',
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          icon: const Icon(Icons.picture_as_pdf_outlined, size: 22, color: SharedTokens.primary),
                          onPressed: () => _frame.canPrint ? _frame.print() : null,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: FarmReportFrame(
                      html: buildAiReportHtml(r, farmName: r.farmName ?? '', orgName: r.orgName ?? ''),
                      controller: _frame,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// On the farm's shared page: the AI 관리 리포트 it has received. Nothing
/// when there are none.
class ReceivedAiReportsStrip extends ConsumerStatefulWidget {
  const ReceivedAiReportsStrip({super.key, required this.token});

  final String token;

  @override
  ConsumerState<ReceivedAiReportsStrip> createState() => _ReceivedAiReportsStripState();
}

class _ReceivedAiReportsStripState extends ConsumerState<ReceivedAiReportsStrip> {
  late final Future<List<AiReport>> _future = ref.read(aiReportRepositoryProvider).listSent(widget.token).catchError((_) => <AiReport>[]);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AiReport>>(
      future: _future,
      builder: (context, snapshot) {
        final reports = snapshot.data ?? const <AiReport>[];
        if (reports.isEmpty) return const SizedBox.shrink();
        final fmt = DateFormat('M월 d일');
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 6),
          decoration: BoxDecoration(color: SharedTokens.card, border: Border.all(color: SharedTokens.line), borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('받은 AI 관리 리포트 ${reports.length}건',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: SharedTokens.text)),
              for (final r in reports)
                InkWell(
                  onTap: () => context.push('/r/${widget.token}/ai/${r.id}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.description_outlined, size: 18, color: SharedTokens.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('${r.periodStart} ~ ${r.periodEnd} · 제${r.version}판',
                              style: const TextStyle(fontSize: 12.5, color: SharedTokens.text)),
                        ),
                        if (r.sentAt != null)
                          Text('${fmt.format(r.sentAt!.toLocal())} 받음', style: const TextStyle(fontSize: 11, color: SharedTokens.textSub)),
                        const Icon(Icons.chevron_right, size: 18, color: SharedTokens.textSub),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
