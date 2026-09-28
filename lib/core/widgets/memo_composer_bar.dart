import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/data_providers.dart';
import '../providers/repository_providers.dart';
import '../theme/app_colors.dart';
import 'memo_composer.dart';

/// The memo composer as a bar pinned to the bottom of a screen (above the
/// tab bar), matching the Memo tab design. Saves through the memo
/// repository, photos included.
class MemoComposerBar extends ConsumerWidget {
  const MemoComposerBar({super.key, this.caption, this.hintText, this.confirmOnSave = false});

  final String? caption;
  final String? hintText;

  /// Show a "saved" snackbar — useful where the memo list isn't on screen.
  final bool confirmOnSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farms = ref.watch(farmsProvider).valueOrNull ?? const [];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 9, 16, 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (caption != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(caption!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
            ),
          MemoComposer(
            farms: farms,
            hintText: hintText ?? "지금 본 것 적어두기 ('/' 로 양식장 지정)",
            onSubmit: (draft) async {
              await ref.read(memoRepositoryProvider).addMemo(
                    farmId: draft.farm?.id,
                    farmName: draft.farm?.name,
                    content: draft.content,
                    tags: draft.tags,
                    photos: draft.photos,
                  );
              if (confirmOnSave && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('메모가 저장되었습니다.')));
              }
            },
          ),
        ],
      ),
    );
  }
}
