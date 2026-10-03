import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/member.dart';
import '../../data/models/memo.dart';
import '../providers/repository_providers.dart';
import '../theme/app_colors.dart';

class MemoCard extends ConsumerWidget {
  const MemoCard({super.key, required this.memo, this.showFarmTag = true});

  final Memo memo;
  final bool showFarmTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(authStateProvider).valueOrNull?.member;
    final isPrivileged = member?.role == MemberRole.owner || member?.role == MemberRole.director;
    // Institute memos can be edited by their author or by an owner/director.
    final canEdit = memo.authorType == MemoAuthorType.institute &&
        member != null &&
        (isPrivileged || memo.authorName.endsWith(member.name));
    final canSeeHistory = isPrivileged && memo.isEdited;
    final isInstitute = memo.authorType == MemoAuthorType.institute;
    final authorBg = isInstitute ? AppColors.brandTint : AppColors.goodTint;
    final authorFg = isInstitute ? AppColors.brand : AppColors.goodDark;
    final displayTags = <String>{
      ...memo.tags,
      if (memo.content.contains('할일:')) '할일',
    }.toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: const Color(0xFFE3E8EF)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              if (showFarmTag) _Pill(text: memo.farmLabel, bg: AppColors.neutralChipStrong, fg: AppColors.textSecondary),
              _Pill(text: memo.authorName, bg: authorBg, fg: authorFg, bold: true),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  memo.content,
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.55),
                ),
              ),
              const SizedBox(width: 8),
              Text(DateFormat('M/d HH:mm').format(memo.createdAt) + (memo.isEdited ? ' · 수정됨' : ''),
                  style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
            ],
          ),
          if (memo.photoCount > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: List.generate(
                memo.photoCount,
                (_) => Container(
                  width: 56,
                  height: 56,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.image_outlined, size: 20, color: AppColors.textMuted),
                ),
              ),
            ),
          ],
          if (displayTags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: displayTags
                  .map((t) => _Pill(text: t, bg: AppColors.neutralChip, fg: AppColors.neutralIcon, small: true))
                  .toList(),
            ),
          ],
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('댓글 달기', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                  if (canEdit) ...[
                    const SizedBox(width: 14),
                    _FooterAction(label: '수정', onTap: () => _showEditSheet(context, ref)),
                  ],
                  if (canSeeHistory) ...[
                    const SizedBox(width: 14),
                    _FooterAction(label: '수정 이력 ${memo.edits.length}', onTap: () => _showHistorySheet(context)),
                  ],
                ],
              ),
              Text(
                memo.readByFarm ? '읽음' : '나만 읽음',
                style: const TextStyle(fontSize: 10.5, color: AppColors.textFaint),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: memo.content);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 16 + MediaQuery.of(sheetContext).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('메모 수정', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text('수정 내용은 원장·소유자가 이력으로 확인할 수 있어요.',
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 3,
              maxLines: 8,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                Navigator.of(sheetContext).pop();
                await ref.read(memoRepositoryProvider).updateMemo(id: memo.id, content: text);
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  void _showHistorySheet(BuildContext context) {
    final fmt = DateFormat('M/d HH:mm');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            children: [
              const Text('수정 이력', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              // Newest edit first; each row shows the text as it stood before that edit.
              for (final e in memo.edits.reversed) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${e.editorName} · ${fmt.format(e.editedAt)}',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.brand)),
                      const SizedBox(height: 4),
                      const Text('수정 전', style: TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                      Text(e.previousContent,
                          style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.5)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              const Text('현재 내용', style: TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
              Text(memo.content, style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary, height: 1.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterAction extends StatelessWidget {
  const _FooterAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.brand)),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.bg, required this.fg, this.bold = false, this.small = false});

  final String text;
  final Color bg;
  final Color fg;
  final bool bold;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        text,
        style: TextStyle(
          fontSize: small ? 10 : 10.5,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
