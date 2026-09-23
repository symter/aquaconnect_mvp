import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/chips.dart';
import '../../data/models/org_member.dart';

/// "구성원 초대" bottom sheet, opened from [MemberManagementScreen]. Once a
/// mock invite link is generated, [onInviteCreated] fires so the caller can
/// add a pending [OrgMember] to its roster.
class InviteMemberSheet extends StatefulWidget {
  const InviteMemberSheet({super.key, required this.onInviteCreated});

  final void Function(MemberRole role, int expireDays) onInviteCreated;

  @override
  State<InviteMemberSheet> createState() => _InviteMemberSheetState();
}

class _InviteMemberSheetState extends State<InviteMemberSheet> {
  MemberRole _role = MemberRole.staff;
  int _expireDays = 7;
  String? _link;

  void _createLink() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    final code = List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
    setState(() => _link = 'aquaconnect.app/invite/$code');
    widget.onInviteCreated(_role, _expireDays);
  }

  void _copyLink() {
    if (_link == null) return;
    Clipboard.setData(ClipboardData(text: _link!));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('링크를 복사했어요')));
  }

  void _notReady(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
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
              const Text('역할', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilterPillChip(
                    label: '원장',
                    selected: _role == MemberRole.director,
                    onTap: () => setState(() => _role = MemberRole.director),
                  ),
                  const SizedBox(width: 8),
                  FilterPillChip(
                    label: '수산질병관리사',
                    selected: _role == MemberRole.staff,
                    onTap: () => setState(() => _role = MemberRole.staff),
                  ),
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
                  FilterPillChip(
                    label: '7일',
                    selected: _expireDays == 7,
                    onTap: () => setState(() => _expireDays = 7),
                  ),
                  const SizedBox(width: 8),
                  FilterPillChip(
                    label: '30일',
                    selected: _expireDays == 30,
                    onTap: () => setState(() => _expireDays = 30),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              PrimaryButton(label: '초대 링크 만들기', onPressed: _createLink),
              if (_link != null) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(_link!,
                            style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_outlined, size: 18, color: AppColors.brand),
                        onPressed: _copyLink,
                        visualDensity: VisualDensity.compact,
                        tooltip: '복사',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _notReady('카카오톡 공유는 준비 중이에요'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.kakaoYellow,
                      foregroundColor: AppColors.kakaoInk,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('카카오톡으로 보내기', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: TextButton(
                    onPressed: () => _notReady('다른 방법으로 공유는 아직 준비 중이에요'),
                    child: const Text('다른 방법으로 공유', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '이 링크로 가입하면 자동으로 우리 관리원에 연결되고, 위에서 선택한 역할로 시작합니다. 링크는 1회만 사용할 수 있어요.',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
