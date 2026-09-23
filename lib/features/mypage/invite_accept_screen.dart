import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/org_member.dart';

/// Mock of the screen someone lands on after tapping an invite link — real
/// entry is a deep link, but for now it's reachable from a temporary MyPage
/// button (see app_router.dart's `/mypage/invite-preview`).
class InviteAcceptScreen extends StatelessWidget {
  const InviteAcceptScreen({
    super.key,
    this.orgName = '함평수산질병관리원',
    this.role = MemberRole.staff,
  });

  final String orgName;
  final MemberRole role;

  void _notReady(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('가입 플로우는 아직 준비 중이에요')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(color: AppColors.brandTint, shape: BoxShape.circle),
                  child: const Icon(Icons.water_outlined, size: 34, color: AppColors.brand),
                ),
                const SizedBox(height: 20),
                Text(
                  '$orgName 에서 초대했어요',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  '$orgName의 ${role.label}(으)로 합류하게 됩니다',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _notReady(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.kakaoYellow,
                      foregroundColor: AppColors.kakaoInk,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('카카오로 계속하기', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _notReady(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brand,
                      side: const BorderSide(color: AppColors.brand, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('휴대폰 번호로 계속하기', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '가입하면 자동으로 이 관리원에 연결됩니다',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
