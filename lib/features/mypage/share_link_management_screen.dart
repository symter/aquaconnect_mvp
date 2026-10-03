import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/data_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/share_link.dart';

/// 마이페이지 > 공유 링크 관리 — every report link issued to farms, with
/// copy and 회수 (revoke: the farm's link stops opening immediately).
class ShareLinkManagementScreen extends ConsumerWidget {
  const ShareLinkManagementScreen({super.key});

  Future<void> _revoke(BuildContext context, WidgetRef ref, ShareLink link) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('링크를 회수할까요?'),
        content: Text('${link.farmName ?? '어가'}에 보낸 이 링크는 바로 열리지 않게 됩니다. 다시 보내려면 새 링크를 만들어야 해요.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('회수하기', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(shareLinkRepositoryProvider).revokeShareLink(link.id);
      ref.invalidate(shareLinksProvider);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('링크를 회수했어요.')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('회수하지 못했어요: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linksAsync = ref.watch(shareLinksProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.brandDark,
        title: const Text('공유 링크 관리', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.brandDark)),
      ),
      body: linksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('공유 링크를 불러오지 못했어요.\n$e', textAlign: TextAlign.center)),
        data: (links) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(shareLinksProvider),
          child: links.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    Icon(Icons.link_off, size: 40, color: AppColors.textFaint),
                    SizedBox(height: 12),
                    Center(
                      child: Text('아직 발급한 공유 링크가 없어요',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                    ),
                    SizedBox(height: 6),
                    Center(
                      child: Text('리포트 화면의 "어가에 리포트 링크 공유"에서 만들 수 있어요.',
                          style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  itemCount: links.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      final active = links.where((l) => l.isActive).length;
                      return Text('열람 가능한 링크 $active개 · 전체 ${links.length}개',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted));
                    }
                    final link = links[i - 1];
                    return _LinkTile(link: link, onRevoke: link.isActive ? () => _revoke(context, ref, link) : null);
                  },
                ),
        ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.link, required this.onRevoke});

  final ShareLink link;
  final VoidCallback? onRevoke;

  String get _url => '${Uri.base.origin}/#${link.urlPath()}';

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('yyyy.M.d');
    final (status, bg, fg) = link.revokedAt != null
        ? ('회수됨', AppColors.neutralChip, AppColors.textMuted)
        : link.isActive
            ? ('열람 가능', AppColors.goodTint, AppColors.good)
            : ('만료', AppColors.warningTint, AppColors.warningDark);
    final until = link.revokedAt != null
        ? '${date.format(link.revokedAt!.toLocal())} 회수'
        : link.expiresAt == null
            ? '기한 없음'
            : '${date.format(link.expiresAt!.toLocal())}까지';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(link.farmName ?? '양식장',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                child: Text(status, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: fg)),
              ),
              const SizedBox(width: 6),
            ],
          ),
          const SizedBox(height: 4),
          Text('${date.format(link.createdAt.toLocal())} 발급 · $until',
              style: const TextStyle(fontSize: 11.5, color: AppColors.textTertiary)),
          if (link.isActive)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: _url));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('링크를 복사했어요.')));
                    }
                  },
                  icon: const Icon(Icons.copy, size: 14),
                  label: const Text('복사', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                TextButton.icon(
                  onPressed: onRevoke,
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                  icon: const Icon(Icons.link_off, size: 14),
                  label: const Text('회수', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
