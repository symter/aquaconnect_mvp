import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/notification_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/app_notification.dart';
import '../../data/services/web_push_service.dart';
import 'push_status_card.dart';

/// "마이페이지 > 알림 설정" — push on/off for this device, which kinds of
/// notifications to get (saved on the server, so it applies on every
/// device), and a test send.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  bool _pushBusy = false;
  bool _testBusy = false;

  void _snack(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _togglePush(bool on) async {
    setState(() => _pushBusy = true);
    try {
      if (on) {
        await enablePushWithFeedback(context, ref);
      } else {
        await ref.read(pushControllerProvider).disable();
        _snack('이 기기의 휴대폰 알림을 껐어요.');
      }
    } catch (e) {
      _snack('변경하지 못했어요: $e');
    } finally {
      if (mounted) setState(() => _pushBusy = false);
    }
  }

  Future<void> _saveSettings(NotificationSettings next) async {
    try {
      await ref.read(notificationSettingsProvider.notifier).save(next);
    } catch (e) {
      _snack('설정을 저장하지 못했어요: $e');
    }
  }

  Future<void> _sendTest() async {
    setState(() => _testBusy = true);
    try {
      await ref.read(notificationRepositoryProvider).sendTest();
      ref.invalidate(notificationFeedProvider);
      final pushOn = ref.read(pushStatusProvider).valueOrNull?.enabled ?? false;
      _snack(pushOn ? '테스트 알림을 보냈어요. 잠시 후 휴대폰 알림을 확인하세요.' : '테스트 알림을 알림함에 보냈어요.');
    } catch (e) {
      _snack('보내지 못했어요: $e');
    } finally {
      if (mounted) setState(() => _testBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(pushStatusProvider);
    final settingsAsync = ref.watch(notificationSettingsProvider);
    final isIos = ref.read(webPushServiceProvider).isIos;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.brandDark,
        title: const Text('알림 설정', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.brandDark)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          const _SectionLabel('이 기기'),
          const SizedBox(height: 8),
          _Group(
            children: [
              statusAsync.when(
                loading: () => const _ToggleRow(
                  icon: Icons.phone_iphone,
                  label: '휴대폰 알림 받기',
                  subtitle: '확인 중…',
                  value: false,
                  onChanged: null,
                ),
                error: (e, _) => _ToggleRow(
                  icon: Icons.phone_iphone,
                  label: '휴대폰 알림 받기',
                  subtitle: '상태를 확인하지 못했어요: $e',
                  value: false,
                  onChanged: null,
                ),
                data: (status) {
                  final canToggle = status.serverAvailable &&
                      status.permission != PushPermission.unsupported &&
                      status.permission != PushPermission.denied;
                  return _ToggleRow(
                    icon: Icons.phone_iphone,
                    label: '휴대폰 알림 받기',
                    subtitle: pushStatusMessage(status, isIos: isIos) ?? '이 기기로 알림을 보내드려요.',
                    value: status.enabled,
                    onChanged: canToggle && !_pushBusy ? _togglePush : null,
                  );
                },
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              InkWell(
                onTap: _testBusy ? null : _sendTest,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.send_outlined, size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(_testBusy ? '보내는 중…' : '테스트 알림 보내기',
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      ),
                      const Icon(Icons.chevron_right, size: 13, color: AppColors.neutralArrow),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SectionLabel('알림 종류'),
          const SizedBox(height: 8),
          settingsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('설정을 불러오지 못했어요.\n$e', style: const TextStyle(color: AppColors.textMuted)),
            data: (settings) => _Group(
              children: [
                _ToggleRow(
                  icon: Icons.warning_amber_rounded,
                  label: '위험도 상승 알림',
                  subtitle: '양식장 위험도가 주의·위험으로 올라가면 알려드려요.',
                  value: settings.riskAlerts,
                  onChanged: (v) => _saveSettings(settings.copyWith(riskAlerts: v)),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _ToggleRow(
                  icon: Icons.edit_note,
                  label: '새 메모 알림',
                  subtitle: '다른 구성원이 메모를 남기면 알려드려요.',
                  value: settings.memoAlerts,
                  onChanged: (v) => _saveSettings(settings.copyWith(memoAlerts: v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('끈 종류의 알림은 알림함에도 쌓이지 않아요. 어가가 공유 리포트에서 보낸 문의 알림은 항상 받아요. 알림 종류 설정은 로그인한 모든 기기에 적용돼요.',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
      child: Column(children: children),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.4)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.brand),
        ],
      ),
    );
  }
}
