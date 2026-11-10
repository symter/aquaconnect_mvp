import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart' show Share;
import 'package:url_launcher/url_launcher.dart';

import '../../data/logic/memo_share_text.dart';
import '../../data/models/memo.dart';
import '../providers/data_providers.dart';
import '../providers/repository_providers.dart';
import '../theme/app_colors.dart';

/// 메모 공유: first pick who it's for, then edit the prepared text.
///  - 양식장에 보내기 → a tidy 안내문 (staff-only bits removed, optional AI
///    다듬기), sent from the member's phone by 카카오톡 or 문자.
///  - 관리원 안에서 공유 → a summary ending with a link that opens this memo.
Future<void> showMemoShareSheet(BuildContext context, Memo memo) async {
  final target = await showModalBottomSheet<_Audience>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Grabber(),
            const SizedBox(height: 12),
            const Text('누구에게 공유할까요?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 14),
            _AudienceTile(
              icon: Icons.storefront_outlined,
              title: '양식장에 보내기',
              body: '카카오톡·문자로 보낼 안내문으로 정리해 드려요. 보내기 전에 고칠 수 있어요.',
              onTap: () => Navigator.of(sheetContext).pop(_Audience.farm),
            ),
            const SizedBox(height: 10),
            _AudienceTile(
              icon: Icons.groups_outlined,
              title: '관리원 안에서 공유',
              body: '정리된 요약 아래에 링크가 붙어요. 링크를 누르면 바로 이 메모가 열려요.',
              onTap: () => Navigator.of(sheetContext).pop(_Audience.internal),
            ),
          ],
        ),
      ),
    ),
  );
  if (target == null || !context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => _ShareComposer(memo: memo, audience: target),
  );
}

enum _Audience { farm, internal }

class _ShareComposer extends ConsumerStatefulWidget {
  const _ShareComposer({required this.memo, required this.audience});
  final Memo memo;
  final _Audience audience;

  @override
  ConsumerState<_ShareComposer> createState() => _ShareComposerState();
}

class _ShareComposerState extends ConsumerState<_ShareComposer> {
  late final TextEditingController _text;
  late final String _draft;
  bool _polishing = false;
  bool _polished = false;
  String? _error;

  bool get _forFarm => widget.audience == _Audience.farm;

  @override
  void initState() {
    super.initState();
    final session = ref.read(authRepositoryProvider).currentSession;
    _draft = _forFarm
        ? farmShareText(
            memo: widget.memo,
            orgName: session?.organization.name ?? '수산질병관리원',
            senderName: session?.member.name ?? '',
            senderPhone: session?.member.phone,
          )
        : internalShareText(memo: widget.memo, link: memoDeepLink(widget.memo.id, origin: Uri.base.origin));
    _text = TextEditingController(text: _draft)..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String? get _farmPhone {
    final farms = ref.watch(farmsProvider).valueOrNull ?? const [];
    for (final f in farms) {
      if (f.id == widget.memo.farmId) {
        final phone = (f.ownerContact ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
        return phone.isEmpty ? null : phone;
      }
    }
    return null;
  }

  Future<void> _polish() async {
    setState(() {
      _polishing = true;
      _error = null;
    });
    try {
      final text = await ref.read(memoRepositoryProvider).polishShareDraft(memoId: widget.memo.id, draft: _text.text);
      if (!mounted) return;
      setState(() {
        _text.text = text;
        _polished = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _polishing = false);
    }
  }

  void _reset() {
    setState(() {
      _text.text = _draft;
      _polished = false;
      _error = null;
    });
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _text.text));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('복사했어요')));
  }

  void _shareApps() {
    Share.share(_text.text, subject: _forFarm ? '${widget.memo.farmLabel} 현장 점검 안내' : '${widget.memo.farmLabel} 현장 메모');
  }

  Future<void> _sms(String phone) async {
    // `?body=` with a percent-encoded body: '+' for spaces shows up
    // literally in some SMS apps.
    final uri = Uri.parse('sms:$phone?body=${Uri.encodeComponent(_text.text)}');
    if (!await launchUrl(uri) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('문자 앱을 열지 못했어요. 복사해서 보내 주세요.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = _forFarm ? _farmPhone : null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            children: [
              const _Grabber(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _forFarm ? '양식장에 보내기' : '관리원 안에서 공유',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Text(
                _forFarm
                    ? '${widget.memo.farmLabel}${phone == null ? ' · 등록된 연락처 없음' : ' · ${_formatPhone(phone)}'}\n'
                        '@호출·할일 같은 내부 표시는 뺐어요. 내용을 확인하고 고쳐서 보내세요.'
                    : '맨 아래 링크를 누르면 로그인 후 바로 이 메모 상세가 열려요.',
                style: const TextStyle(fontSize: 12, height: 1.5, color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _text,
                minLines: 10,
                maxLines: 18,
                enabled: !_polishing,
                style: const TextStyle(fontSize: 13.5, height: 1.55, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (_forFarm)
                    TextButton.icon(
                      onPressed: _polishing ? null : _polish,
                      icon: _polishing
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.auto_awesome, size: 16),
                      label: Text(_polishing ? '다듬는 중…' : (_polished ? 'AI로 다시 다듬기' : 'AI로 문장 다듬기')),
                    ),
                  const Spacer(),
                  if (_text.text != _draft)
                    TextButton(
                      onPressed: _polishing ? null : _reset,
                      child: const Text('처음 초안으로', style: TextStyle(color: AppColors.textMuted)),
                    ),
                ],
              ),
              if (_polished)
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text('AI가 다듬은 문장이에요. 수치·날짜가 메모와 같은지 꼭 확인해 주세요.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.warningDark)),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(_error!, style: const TextStyle(fontSize: 11.5, color: AppColors.danger)),
                ),
              const SizedBox(height: 10),
              if (_forFarm) ...[
                Row(
                  children: [
                    Expanded(
                      child: _SendButton(
                        icon: Icons.chat_bubble,
                        label: '카카오톡 등으로',
                        background: AppColors.kakaoYellow,
                        foreground: AppColors.kakaoInk,
                        onTap: _polishing ? null : _shareApps,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SendButton(
                        icon: Icons.sms_outlined,
                        label: '문자 보내기',
                        background: AppColors.brand,
                        foreground: Colors.white,
                        onTap: _polishing || phone == null ? null : () => _sms(phone),
                      ),
                    ),
                  ],
                ),
              ] else
                _SendButton(
                  icon: Icons.ios_share,
                  label: '공유하기',
                  background: AppColors.brand,
                  foreground: Colors.white,
                  onTap: _shareApps,
                ),
              const SizedBox(height: 4),
              Center(
                child: TextButton.icon(
                  onPressed: _copy,
                  icon: const Icon(Icons.copy, size: 15, color: AppColors.textSecondary),
                  label: const Text('텍스트 복사', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatPhone(String digits) {
  if (digits.length == 11) return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
  if (digits.length == 10) return '${digits.substring(0, 3)}-${digits.substring(3, 6)}-${digits.substring(6)}';
  return digits;
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
      ),
    );
  }
}

class _AudienceTile extends StatelessWidget {
  const _AudienceTile({required this.icon, required this.title, required this.body, required this.onTap});
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(side: const BorderSide(color: AppColors.border), borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: AppColors.brandTint, shape: BoxShape.circle),
                child: Icon(icon, size: 20, color: AppColors.brand),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const SizedBox(height: 3),
                    Text(body, style: const TextStyle(fontSize: 12, height: 1.45, color: AppColors.textMuted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: AppColors.neutralArrow),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.icon, required this.label, required this.background, required this.foreground, required this.onTap});
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
