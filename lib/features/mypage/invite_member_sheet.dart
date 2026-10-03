import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart' show Share;

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/chips.dart';
import '../../data/models/invitation.dart';
import '../../data/models/org_member.dart';

/// "구성원 초대" bottom sheet, opened from [MemberManagementScreen]. Creates
/// a single-use invite link on the server; [onCreated] lets the roster
/// reload its pending list.
class InviteMemberSheet extends ConsumerStatefulWidget {
  const InviteMemberSheet({super.key, required this.onCreated});

  final VoidCallback onCreated;

  @override
  ConsumerState<InviteMemberSheet> createState() => _InviteMemberSheetState();
}

class _InviteMemberSheetState extends ConsumerState<InviteMemberSheet> {
  MemberRole _role = MemberRole.staff;
  int _expireDays = 7;
  final _note = TextEditingController();
  Invitation? _invite;
  bool _creating = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final invite = await ref
          .read(orgRepositoryProvider)
          .createInvitation(role: _role, expireDays: _expireDays, note: _note.text.trim());
      widget.onCreated();
      if (mounted) setState(() => _invite = invite);
    } catch (e) {
      if (mounted) setState(() => _error = '초대 링크를 만들지 못했어요: $e');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _invite!.url));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('링크를 복사했어요')));
  }

  void _share() {
    final orgName = ref.read(authRepositoryProvider).currentSession?.organization.name ?? 'AquaConnect';
    Share.share(
      '$orgName에서 ${_invite!.role.label}(으)로 초대했어요. 아래 링크에서 가입하면 바로 함께할 수 있어요.\n${_invite!.url}',
      subject: '$orgName 구성원 초대',
    );
  }

  @override
  Widget build(BuildContext context) {
    final invite = _invite;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const Text('구성원 초대', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.brandDark)),
              const SizedBox(height: 18),
              if (invite == null) ..._form() else ..._result(invite),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _form() => [
        const Text('역할', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final role in [MemberRole.director, MemberRole.staff, MemberRole.employee])
              FilterPillChip(label: role.label, selected: _role == role, onTap: () => setState(() => _role = role)),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          '소유자 권한은 초대로 줄 수 없어요. 소유자 변경은 구성원 목록에서 진행하세요',
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        const SizedBox(height: 18),
        const Text('만료 기한', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Row(
          children: [
            FilterPillChip(label: '7일', selected: _expireDays == 7, onTap: () => setState(() => _expireDays = 7)),
            const SizedBox(width: 8),
            FilterPillChip(label: '30일', selected: _expireDays == 30, onTap: () => setState(() => _expireDays = 30)),
          ],
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _note,
          maxLength: 60,
          decoration: InputDecoration(
            labelText: '받는 사람 (선택)',
            hintText: '예) 김관리 010-1234-5678',
            helperText: '초대 대기 목록에서 누구에게 보낸 초대인지 알아보기 위한 메모예요.',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            isDense: true,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.danger)),
        ],
        const SizedBox(height: 12),
        PrimaryButton(label: _creating ? '만드는 중...' : '초대 링크 만들기', onPressed: _creating ? null : _create),
      ];

  List<Widget> _result(Invitation invite) => [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.goodTint, borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              const Icon(Icons.check_circle, size: 18, color: AppColors.good),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${invite.role.label} 초대 링크를 만들었어요 · ${invite.expiresAt.month}월 ${invite.expiresAt.day}일까지',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.good),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(invite.url,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                icon: const Icon(Icons.copy_outlined, size: 18, color: AppColors.brand),
                onPressed: _copy,
                visualDensity: VisualDensity.compact,
                tooltip: '복사',
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _share,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.ios_share, size: 16),
            label: const Text('문자·카카오톡으로 보내기', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          '이 링크로 가입하면 자동으로 우리 관리원에 연결되고, 위에서 선택한 역할로 시작합니다. 링크는 1회만 사용할 수 있어요.',
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ];
}
