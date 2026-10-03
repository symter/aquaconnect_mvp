import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/notification_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/web_push_service.dart';

/// Why push can't be (or isn't yet) on for this device, in words the user
/// can act on. Null when push is fully on.
String? pushStatusMessage(PushStatus status, {required bool isIos}) {
  if (status.permission == PushPermission.unsupported) {
    return isIos
        ? '아이폰은 Safari 공유 버튼 → "홈 화면에 추가"로 앱을 설치한 뒤, 홈 화면의 AquaConnect에서 알림을 켤 수 있어요.'
        : '이 브라우저는 휴대폰 알림을 지원하지 않아요. Chrome 같은 최신 브라우저에서 열어주세요.';
  }
  if (!status.serverAvailable) return 'Mock 모드에서는 휴대폰 알림을 받을 수 없어요.';
  if (status.permission == PushPermission.denied) {
    return '알림이 차단되어 있어요. 브라우저(또는 휴대폰) 설정 > 사이트 설정 > 알림에서 이 사이트를 "허용"으로 바꿔주세요.';
  }
  if (!status.enabled) return '휴대폰 알림이 꺼져 있어요. 켜면 앱을 닫아도 새 알림을 받을 수 있어요.';
  return null;
}

/// Enables push from a tap, reporting the outcome in a snackbar.
Future<void> enablePushWithFeedback(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final permission = await ref.read(pushControllerProvider).enable();
    messenger.showSnackBar(SnackBar(
      content: Text(switch (permission) {
        PushPermission.granted => '휴대폰 알림을 켰어요.',
        PushPermission.denied => '알림 권한이 거부되었어요. 설정에서 허용으로 바꿀 수 있어요.',
        _ => '알림 권한을 허용하지 않았어요.',
      }),
    ));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('알림을 켜지 못했어요: $e')));
  }
}

/// Banner on 알림함 showing whether this device gets push, with a button
/// to turn it on when that's possible.
class PushStatusCard extends ConsumerWidget {
  const PushStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(pushStatusProvider).valueOrNull;
    if (status == null || status.enabled) return const SizedBox.shrink();
    final message = pushStatusMessage(status, isIos: ref.read(webPushServiceProvider).isIos);
    final canEnable = status.serverAvailable &&
        (status.permission == PushPermission.notAsked || status.permission == PushPermission.granted);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: AppColors.brandTintStrong, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.notifications_active_outlined, size: 18, color: AppColors.brand),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message ?? '', style: const TextStyle(fontSize: 12, color: AppColors.brandInk, height: 1.5)),
                if (canEnable) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 32,
                    child: ElevatedButton(
                      onPressed: () => enablePushWithFeedback(context, ref),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('휴대폰 알림 켜기', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
