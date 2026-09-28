import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/memo.dart';
import '../providers/data_providers.dart';
import '../theme/app_colors.dart';

class MemoCard extends StatelessWidget {
  const MemoCard({super.key, required this.memo, this.showFarmTag = true});

  final Memo memo;
  final bool showFarmTag;

  @override
  Widget build(BuildContext context) {
    final isInstitute = memo.authorType == MemoAuthorType.institute;
    final authorBg = isInstitute ? AppColors.brandTint : AppColors.goodTint;
    final authorFg = isInstitute ? AppColors.brand : AppColors.goodDark;

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
              Text(DateFormat('M/d HH:mm').format(memo.createdAt),
                  style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
            ],
          ),
          if (memo.photoIds.isNotEmpty || memo.photoCount > 0) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final id in memo.photoIds) _MemoPhotoThumb(photoId: id),
                // Seed memos only carry a count, not stored images.
                for (var i = memo.photoIds.length; i < memo.photoCount; i++) const _PhotoPlaceholder(),
              ],
            ),
          ],
          if (memo.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: memo.tags
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
              const Text('댓글 달기', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
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
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({this.child = const Icon(Icons.image_outlined, size: 20, color: AppColors.textMuted)});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(8)),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _MemoPhotoThumb extends ConsumerWidget {
  const _MemoPhotoThumb({required this.photoId});

  final String photoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(memoPhotoProvider(photoId)).when(
          data: (bytes) => GestureDetector(
            onTap: () => _openViewer(context, bytes),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(bytes, width: 56, height: 56, fit: BoxFit.cover),
            ),
          ),
          loading: () => const _PhotoPlaceholder(
            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, _) => const _PhotoPlaceholder(
            child: Icon(Icons.broken_image_outlined, size: 20, color: AppColors.textMuted),
          ),
        );
  }

  void _openViewer(BuildContext context, Uint8List bytes) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) => GestureDetector(
        onTap: () => Navigator.of(dialogContext).pop(),
        child: Stack(
          children: [
            Center(child: InteractiveViewer(child: Image.memory(bytes))),
            Positioned(
              top: 12,
              right: 12,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ),
          ],
        ),
      ),
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
