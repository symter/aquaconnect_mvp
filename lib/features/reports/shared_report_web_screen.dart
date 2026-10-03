import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers/repository_providers.dart';
import '../../data/logic/farm_monthly_report_builder.dart';
import '../../data/models/farm.dart';
import '../../data/models/farm_monthly_report.dart';
import '../../data/models/report.dart';
import 'farm_report_frame.dart';
import 'farm_report_html.dart';
import 'inquiry_sheet.dart';
import 'share_link_sheet.dart';
import 'shared_report_tokens.dart';

/// Public, unauthenticated `/r/:token` page — what a farm owner opens on
/// their own phone after the institute sends the share link. Shows the
/// monthly 관리 리포트 ([buildFarmReportHtml]), which can be saved as PDF,
/// plus the inquiry sheet.
///
/// [SharedReportWebScreen.preview] renders the same page inside the
/// institute app (홈·전체 리포트 → 양식장) so staff can check what the farm
/// will receive; there the bottom bar offers 메모 남기기 and the
/// share-link sheet instead of the inquiry sheet.
class SharedReportWebScreen extends ConsumerStatefulWidget {
  const SharedReportWebScreen({super.key, required String this.token}) : farmId = null;

  const SharedReportWebScreen.preview({super.key, required String this.farmId}) : token = null;

  final String? token;
  final String? farmId;

  bool get isPreview => farmId != null;

  @override
  ConsumerState<SharedReportWebScreen> createState() => _SharedReportWebScreenState();
}

class _Loaded {
  const _Loaded({required this.farm, required this.report, required this.html, required this.orgName, this.phone});

  final Farm farm;
  final FarmMonthlyReport report;
  final String html;
  final String orgName;

  /// The assigned staff member's phone, for the inquiry sheet's 전화 걸기.
  final String? phone;
}

class _SharedReportWebScreenState extends ConsumerState<SharedReportWebScreen> {
  late final Future<_Loaded?> _future = widget.isPreview ? _loadPreview() : _load();
  final _frame = FarmReportFrameController();

  Future<_Loaded?> _load() async {
    final bundle = await ref.read(shareLinkRepositoryProvider).resolveToken(widget.token!);
    if (bundle == null) return null;
    final orgName = (bundle.organizationName?.isNotEmpty ?? false) ? bundle.organizationName! : '수산질병관리원';
    return _build(bundle.farm, bundle.report, orgName: orgName, phone: bundle.assignedMemberPhone);
  }

  Future<_Loaded?> _loadPreview() async {
    final farm = await ref.read(farmRepositoryProvider).getFarm(widget.farmId!);
    if (farm == null) return null;
    final report = await ref.read(reportRepositoryProvider).getLatestReport(farm.id);
    final orgName = ref.read(authStateProvider).valueOrNull?.organization.name ?? '수산질병관리원';
    return _build(farm, report, orgName: orgName, phone: farm.assignedMemberPhone);
  }

  _Loaded _build(Farm farm, Report? report, {required String orgName, String? phone}) {
    final monthly = FarmMonthlyReportBuilder.build(farm, report: report, orgName: orgName, managerPhone: phone);
    return _Loaded(
      farm: farm,
      report: monthly,
      html: buildFarmReportHtml(monthly),
      orgName: orgName,
      phone: (phone?.isNotEmpty ?? false) ? phone : null,
    );
  }

  Future<void> _sendInquiry(String message) =>
      ref.read(shareLinkRepositoryProvider).sendInquiry(token: widget.token!, message: message);

  void _openInquiry(_Loaded loaded) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: SharedTokens.scrim,
      constraints: const BoxConstraints(maxWidth: SharedTokens.maxWidth),
      builder: (_) => InquirySheet(orgName: loaded.orgName, phone: loaded.phone, onSend: _sendInquiry),
    );
  }

  void _savePdf() {
    if (_frame.canPrint) {
      _frame.print();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('리포트를 불러온 뒤 다시 시도해 주세요.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(textTheme: GoogleFonts.notoSansKrTextTheme(Theme.of(context).textTheme)),
      child: Scaffold(
        backgroundColor: SharedTokens.outerBg,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: SharedTokens.maxWidth),
            child: ColoredBox(
              color: SharedTokens.bg,
              child: FutureBuilder<_Loaded?>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator(color: SharedTokens.primary));
                  }
                  final loaded = snapshot.data;
                  if (loaded == null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(widget.isPreview ? '양식장을 찾을 수 없습니다.' : '링크가 만료되었거나 존재하지 않습니다.',
                            style: const TextStyle(color: SharedTokens.textSub)),
                      ),
                    );
                  }
                  return SafeArea(
                    child: Column(
                      children: [
                        _Header(farmName: loaded.farm.name, onSavePdf: _savePdf),
                        if (widget.isPreview)
                          const Padding(padding: EdgeInsets.fromLTRB(12, 10, 12, 0), child: _PreviewBanner()),
                        Expanded(child: FarmReportFrame(html: loaded.html, controller: _frame)),
                        if (!widget.isPreview)
                          _InquiryCta(orgName: loaded.orgName, onTap: () => _openInquiry(loaded))
                        else
                          _PreviewActions(
                            onMemo: () => context.go('/memo'),
                            onShare: () => showShareLinkSheet(context, farm: loaded.farm),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewBanner extends StatelessWidget {
  const _PreviewBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF3E1),
        border: Border.all(color: const Color(0xFFF1D6A6)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF9A6A12)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '어가 화면 미리보기입니다. 어가가 공유 링크를 열면 아래 리포트를 보게 되고, 문의는 어가에서만 할 수 있습니다.',
              style: TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF7A5410)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.farmName, required this.onSavePdf});

  final String farmName;

  /// Opens the browser print dialog, where "PDF로 저장" keeps the A4 layout.
  final VoidCallback onSavePdf;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: const BoxDecoration(color: SharedTokens.card, border: Border(bottom: BorderSide(color: SharedTokens.line))),
      child: Row(
        children: [
          // The farm opens the share link as the first page, so there's
          // nothing to go back to — keep the slot so the title stays centered.
          if (context.canPop())
            IconButton(
              tooltip: '뒤로가기',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: SharedTokens.text),
              onPressed: () => context.pop(),
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: Column(
              children: [
                const Text('양식장 관리 리포트', style: TextStyle(fontSize: 11, color: SharedTokens.textSub, fontWeight: FontWeight.w500)),
                const SizedBox(height: 1),
                Text(farmName,
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
            onPressed: onSavePdf,
          ),
        ],
      ),
    );
  }
}

class _InquiryCta extends StatelessWidget {
  const _InquiryCta({required this.orgName, required this.onTap});

  final String orgName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(color: SharedTokens.card, border: Border(top: BorderSide(color: SharedTokens.line))),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: SharedTokens.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: const Icon(Icons.chat_bubble_outline, size: 18),
          label: Text('$orgName에 문의하기', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}

/// Preview-mode replacement for [_InquiryCta]: leave a memo about this
/// farm, or send the report to the farm.
class _PreviewActions extends StatelessWidget {
  const _PreviewActions({required this.onMemo, required this.onShare});

  final VoidCallback onMemo;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(color: SharedTokens.card, border: Border(top: BorderSide(color: SharedTokens.line))),
      child: SizedBox(
        height: 52,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                onPressed: onMemo,
                style: OutlinedButton.styleFrom(
                  foregroundColor: SharedTokens.primary,
                  side: const BorderSide(color: SharedTokens.primary),
                  shape: shape,
                ),
                icon: const Icon(Icons.edit_note, size: 18),
                label: const Text('메모 남기기', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: FilledButton.icon(
                onPressed: onShare,
                style: FilledButton.styleFrom(backgroundColor: SharedTokens.primary, shape: shape),
                icon: const Icon(Icons.link, size: 18),
                label: const Text('어가에 링크 공유', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
