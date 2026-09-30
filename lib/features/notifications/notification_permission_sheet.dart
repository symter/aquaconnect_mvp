import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/notification_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/buttons.dart';
import '../../data/services/web_push_service.dart';
import 'push_status_card.dart';

/// Home's bell: the first time (permission never asked) it explains what
/// notifications are for and asks for permission, then opens the 알림함.
Future<void> openNotifications(BuildContext context, WidgetRef ref) async {
  final push = ref.read(webPushServiceProvider);
  if (push.permission == PushPermission.notAsked) {
    await showModalBottomSheet<void>(
      context: context,
      // Home lives in a tab branch; the root navigator puts the sheet above
      // the bottom tab bar instead of underneath it.
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _PermissionSheet(),
    );
  } else if (push.permission == PushPermission.granted) {
    // Quietly (re)register in case this device was subscribed under a
    // different login or before a server reset.
    ref.read(pushControllerProvider).syncIfGranted();
  }
  if (context.mounted) context.push('/notifications');
}

class _PermissionSheet extends ConsumerStatefulWidget {
  const _PermissionSheet();

  @override
  ConsumerState<_PermissionSheet> createState() => _PermissionSheetState();
}

class _PermissionSheetState extends ConsumerState<_PermissionSheet> {
  bool _busy = false;

  Future<void> _allow() async {
    setState(() => _busy = true);
    // Must start from this tap: browsers only show the prompt for a user
    // gesture.
    await enablePushWithFeedback(context, ref);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
            ),
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(color: AppColors.brandTint, shape: BoxShape.circle),
              child: const Icon(Icons.notifications_active_outlined, size: 28, color: AppColors.brand),
            ),
            const SizedBox(height: 14),
            const Text('알림을 받아보세요',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text(
              '양식장 위험도가 올라가거나 다른 구성원이 메모를 남기면\n앱을 닫아둬도 휴대폰으로 알려드려요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 6),
            const Text(
              '다음 화면에서 브라우저가 알림 권한을 물으면 "허용"을 눌러주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: _busy ? '설정 중...' : '알림 허용하기', onPressed: _busy ? null : _allow),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: const Text('나중에', style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
            ),
          ],
        ),
      ),
    );
  }
}
