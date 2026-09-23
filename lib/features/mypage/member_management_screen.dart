import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/buttons.dart';
import '../../data/models/org_member.dart';
import 'invite_member_sheet.dart';

/// "마이페이지 > 구성원 관리" — roster of the org's members plus pending
/// invites. MVP-stage: role is a display label only, no permission
/// branching — every signed-in user sees every action button.
class MemberManagementScreen extends StatefulWidget {
  const MemberManagementScreen({super.key});

  @override
  State<MemberManagementScreen> createState() => _MemberManagementScreenState();
}

class _MemberManagementScreenState extends State<MemberManagementScreen> {
  final List<OrgMember> _members = mockOrgMembers();

  List<OrgMember> get _active => _members.where((m) => m.status == MemberStatus.active).toList();
  List<OrgMember> get _pending => _members.where((m) => m.status == MemberStatus.pending).toList();
  List<OrgMember> get _inactive => _members.where((m) => m.status == MemberStatus.inactive).toList();

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openInviteSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => InviteMemberSheet(
        onInviteCreated: (role, expireDays) {
          setState(() {
            _members.add(OrgMember(
              id: 'om-${DateTime.now().microsecondsSinceEpoch}',
              name: '010-0000-0000',
              role: role,
              status: MemberStatus.pending,
              joinedAt: DateTime.now(),
              inviteTarget: '010-0000-0000',
              inviteExpiresAt: DateTime.now().add(Duration(days: expireDays)),
            ));
          });
        },
      ),
    );
  }

  void _setRole(OrgMember member, MemberRole role) {
    setState(() {
      final i = _members.indexWhere((m) => m.id == member.id);
      _members[i] = _members[i].copyWith(role: role);
    });
    _snack('${member.name}님을 ${role.label}(으)로 지정했어요');
  }

  Future<void> _confirmDeactivate(OrgMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${member.name}님을 비활성화할까요?'),
        content: const Text('비활성화하면 로그인할 수 없지만, 이 구성원이 남긴 기록은 양식장에 그대로 남습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('비활성화', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      final i = _members.indexWhere((m) => m.id == member.id);
      _members[i] = _members[i].copyWith(status: MemberStatus.inactive);
    });
    _snack('비활성화했어요');
  }

  Future<void> _confirmTransferOwner(OrgMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('소유자를 양도할까요?'),
        content: Text(
          '${member.name}님이 소유자가 되고, 회원님은 원장으로 전환됩니다. 이 작업은 되돌리려면 새로운 소유자가 다시 양도해야 합니다.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('양도하기', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      final ownerIndex = _members.indexWhere((m) => m.role == MemberRole.owner);
      final targetIndex = _members.indexWhere((m) => m.id == member.id);
      _members[ownerIndex] = _members[ownerIndex].copyWith(role: MemberRole.director);
      _members[targetIndex] = _members[targetIndex].copyWith(role: MemberRole.owner);
    });
    _snack('소유자를 양도했어요');
  }

  void _showMemberActions(OrgMember member) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
              ),
              if (member.role == MemberRole.owner)
                // Ownership is transferred *to* someone — there's nothing to
                // offer on the owner's own row (see the other branch below,
                // which now correctly puts "소유자로 지정" on every other
                // member's row instead).
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    '소유자는 다른 구성원 목록에서 "소유자로 지정"을 선택해 양도할 수 있어요.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                )
              else ...[
                for (final role in [MemberRole.director, MemberRole.staff, MemberRole.employee])
                  if (role != member.role)
                    ListTile(
                      leading: const Icon(Icons.badge_outlined, color: AppColors.textSecondary),
                      title: Text('${role.label}(으)로 지정'),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _setRole(member, role);
                      },
                    ),
                ListTile(
                  leading: const Icon(Icons.swap_horiz, color: AppColors.textSecondary),
                  title: const Text('소유자로 지정'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _confirmTransferOwner(member);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_off_outlined, color: AppColors.danger),
                  title: const Text('비활성화', style: TextStyle(color: AppColors.danger)),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _confirmDeactivate(member);
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _resendInvite(OrgMember invite) {
    setState(() {
      final i = _members.indexWhere((m) => m.id == invite.id);
      final original = _members[i];
      final now = DateTime.now();
      // Renew for the same duration originally granted, rather than leaving
      // the old absolute expiry in place — otherwise "resend" doesn't
      // actually extend the invite's life.
      final duration = original.inviteExpiresAt?.difference(original.joinedAt) ?? const Duration(days: 7);
      _members[i] = original.copyWith(joinedAt: now, inviteExpiresAt: now.add(duration));
    });
    _snack('다시 발송했어요');
  }

  void _cancelInvite(OrgMember invite) {
    final index = _members.indexWhere((m) => m.id == invite.id);
    final removed = _members[index];
    setState(() => _members.removeAt(index));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('초대를 취소했어요'),
        action: SnackBarAction(
          label: '실행취소',
          onPressed: () => setState(() => _members.insert(index.clamp(0, _members.length), removed)),
        ),
      ),
    );
  }

  void _reactivate(OrgMember member) {
    setState(() {
      final i = _members.indexWhere((m) => m.id == member.id);
      _members[i] = _members[i].copyWith(status: MemberStatus.active);
    });
    _snack('다시 활성화했어요');
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    final pending = _pending;
    final inactive = _inactive;
    final isEmpty = active.length == 1 && active.first.isMe && pending.isEmpty && inactive.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.brandDark,
        title: const Text('구성원 관리', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.brandDark)),
        actions: [
          TextButton(
            onPressed: _openInviteSheet,
            child: const Text('+ 초대', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.brand)),
          ),
        ],
      ),
      body: isEmpty ? _EmptyState(onInvite: _openInviteSheet) : _buildList(active, pending, inactive),
    );
  }

  Widget _buildList(List<OrgMember> active, List<OrgMember> pending, List<OrgMember> inactive) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text('구성원 ${active.length}명', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(height: 12),
        for (final member in active) ...[
          _ActiveMemberTile(member: member, onMore: () => _showMemberActions(member)),
          const SizedBox(height: 8),
        ],
        if (pending.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          const Text('초대 대기 중', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          for (final invite in pending) ...[
            _PendingInviteTile(
              invite: invite,
              onResend: () => _resendInvite(invite),
              onCancel: () => _cancelInvite(invite),
            ),
            const SizedBox(height: 8),
          ],
        ],
        if (inactive.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Divider(),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text('비활성 구성원 (${inactive.length})',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              children: [
                for (final member in inactive)
                  _InactiveMemberTile(member: member, onReactivate: () => _reactivate(member)),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onInvite});
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.groups_outlined, size: 40, color: AppColors.textFaint),
            const SizedBox(height: 12),
            const Text('아직 함께하는 구성원이 없어요',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
            const SizedBox(height: 20),
            PrimaryButton(label: '+ 초대하기', onPressed: onInvite),
          ],
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role, this.muted = false});
  final MemberRole role;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final filled = role == MemberRole.owner && !muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? AppColors.brand : (muted ? AppColors.neutralChip : AppColors.surface),
        border: filled ? null : Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role.label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: filled ? Colors.white : (muted ? AppColors.textMuted : AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _ActiveMemberTile extends StatelessWidget {
  const _ActiveMemberTile({required this.member, required this.onMore});
  final OrgMember member;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.brandTint,
            child: Text(
              member.name.isEmpty ? '?' : member.name.substring(0, 1),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.brand),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(member.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ),
                    if (member.isMe) ...[
                      const SizedBox(width: 4),
                      const Text('(나)', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                    ],
                    const SizedBox(width: 6),
                    _RoleBadge(role: member.role),
                  ],
                ),
                const SizedBox(height: 3),
                Text(DateFormat('yyyy.MM.dd').format(member.joinedAt),
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textTertiary),
            onPressed: onMore,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _PendingInviteTile extends StatelessWidget {
  const _PendingInviteTile({required this.invite, required this.onResend, required this.onCancel});
  final OrgMember invite;
  final VoidCallback onResend;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final expiresIn = invite.inviteExpiresAt?.difference(DateTime.now()).inDays;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(invite.inviteTarget ?? invite.name,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ),
              _RoleBadge(role: invite.role),
              const SizedBox(width: 8),
              Text(
                expiresIn == null ? '' : '만료 D-${expiresIn < 0 ? 0 : expiresIn}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.warning),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: onResend,
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: const Text('재전송', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.brand)),
              ),
              const SizedBox(width: 16),
              TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: const Text('취소', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InactiveMemberTile extends StatelessWidget {
  const _InactiveMemberTile({required this.member, required this.onReactivate});
  final OrgMember member;
  final VoidCallback onReactivate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(member.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                ),
                const SizedBox(width: 4),
                const Text('(비활성)', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                const SizedBox(width: 6),
                _RoleBadge(role: member.role, muted: true),
              ],
            ),
          ),
          TextButton(
            onPressed: onReactivate,
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: const Text('재활성화', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.brand)),
          ),
        ],
      ),
    );
  }
}
