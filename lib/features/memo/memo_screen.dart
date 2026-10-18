import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers/data_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/memo_card.dart';
import '../../core/widgets/memo_composer_bar.dart';
import '../../data/models/memo.dart';

class MemoScreen extends ConsumerStatefulWidget {
  const MemoScreen({super.key, this.focusMemoId, this.openComments = false});

  /// Memo to pin at the top, from a tapped memo/comment notification.
  final String? focusMemoId;

  /// Also open [focusMemoId]'s 댓글 sheet (a comment notification).
  final bool openComments;

  @override
  ConsumerState<MemoScreen> createState() => _MemoScreenState();
}

class _MemoScreenState extends ConsumerState<MemoScreen> {
  String _filter = '전체';
  bool _searching = false;
  String _query = '';
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  String? _focusId;
  bool _commentsPending = false;

  @override
  void initState() {
    super.initState();
    _takeFocus();
  }

  @override
  void didUpdateWidget(MemoScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusMemoId != oldWidget.focusMemoId) _takeFocus();
  }

  /// Picks up `?memo=` from the route, then clears it from the location so
  /// the same notification tapped again (or the 메모 tab restoring its last
  /// location) is seen as a fresh request.
  void _takeFocus() {
    final id = widget.focusMemoId;
    if (id == null) return;
    _focusId = id;
    _commentsPending = widget.openComments;
    _filter = '전체';
    _searching = false;
    _query = '';
    _searchController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/memo');
    });
  }

  /// Opens the pending 댓글 sheet once the focused memo is in the list.
  void _openPendingComments(Memo memo) {
    _commentsPending = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) MemoCard(memo: memo).showComments(context);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _searching = true);
    _searchFocus.requestFocus();
  }

  void _closeSearch() {
    _searchController.clear();
    _searchFocus.unfocus();
    setState(() {
      _searching = false;
      _query = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final farmsAsync = ref.watch(farmsProvider);
    final memosAsync = ref.watch(memosProvider(null));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_searching)
                    _SearchField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      onChanged: (v) => setState(() => _query = v),
                      onClose: _closeSearch,
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('메모', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.brandDark)),
                        IconButton(
                          tooltip: '메모 검색',
                          onPressed: _openSearch,
                          icon: const Icon(Icons.search, size: 20, color: AppColors.neutralIconStrong),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  farmsAsync.when(
                    data: (farms) => SizedBox(
                      height: 30,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          FilterPillChip(label: '전체', selected: _filter == '전체', onTap: () => setState(() => _filter = '전체')),
                          const SizedBox(width: 6),
                          FilterPillChip(label: '할일', selected: _filter == '할일', onTap: () => setState(() => _filter = '할일')),
                          const SizedBox(width: 6),
                          FilterPillChip(label: '미지정', selected: _filter == '미지정', onTap: () => setState(() => _filter = '미지정')),
                          const SizedBox(width: 6),
                          for (final farm in farms) ...[
                            FilterPillChip(label: farm.name, selected: _filter == farm.id, onTap: () => setState(() => _filter = farm.id)),
                            const SizedBox(width: 6),
                          ],
                        ],
                      ),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: memosAsync.when(
                data: (memos) {
                  // Not found (yet, or deleted): just the normal list.
                  final focused = memos.where((m) => m.id == _focusId).firstOrNull;
                  if (focused != null && _commentsPending) _openPendingComments(focused);
                  final filtered = _applyFilter(memos).where((m) => m.id != focused?.id).toList();
                  final groups = _groupByDay(filtered);
                  if (filtered.isEmpty && focused == null) {
                    return Center(
                      child: Text(
                        _query.trim().isEmpty ? '아직 메모가 없습니다.' : "'${_query.trim()}'에 해당하는 메모가 없습니다.",
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                    children: [
                      if (focused != null) ...[
                        Row(
                          children: [
                            const Icon(Icons.notifications_active_outlined, size: 14, color: AppColors.brand),
                            const SizedBox(width: 4),
                            const Expanded(
                              child: Text('알림에서 연 메모',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.brand)),
                            ),
                            IconButton(
                              tooltip: '닫기',
                              onPressed: () => setState(() => _focusId = null),
                              icon: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.brandTintBorder, width: 2),
                          ),
                          child: MemoCard(memo: focused),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (_query.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(2, 0, 2, 4),
                          child: Text('검색 결과 ${filtered.length}건',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.brand)),
                        ),
                      for (final entry in groups.entries) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
                          child: Text(entry.key,
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                        ),
                        const SizedBox(height: 8),
                        for (final memo in entry.value) ...[
                          MemoCard(memo: memo),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('불러오기 실패: $e')),
              ),
            ),
            const MemoComposerBar(
              caption: '자세히 기록하기 · 양식장 태그·표현·사진을 한 번에',
              hintText: "/ 로 양식장 지정",
            ),
          ],
        ),
      ),
    );
  }

  List<Memo> _applyFilter(List<Memo> memos) {
    final byFarm = switch (_filter) {
      '전체' => memos,
      '할일' => memos.where((m) => m.tags.contains('할일') || m.content.contains('할일:')).toList(),
      '미지정' => memos.where((m) => m.farmId == null).toList(),
      _ => memos.where((m) => m.farmId == _filter).toList(),
    };
    return byFarm.where(_matchesQuery).toList();
  }

  /// Every whitespace-separated word must appear somewhere in the memo's
  /// content, tags, farm name or author (case-insensitive).
  bool _matchesQuery(Memo memo) {
    final words = _query.trim().toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return true;
    final haystack = [memo.content, ...memo.tags, memo.farmLabel, memo.authorName].join(' ').toLowerCase();
    return words.every(haystack.contains);
  }

  Map<String, List<Memo>> _groupByDay(List<Memo> memos) {
    final formatter = DateFormat('M월 d일 EEEE', 'ko_KR');
    final map = <String, List<Memo>>{};
    for (final memo in memos) {
      final label = _safeFormat(formatter, memo.createdAt);
      map.putIfAbsent(label, () => []).add(memo);
    }
    return map;
  }

  String _safeFormat(DateFormat formatter, DateTime dt) {
    try {
      return formatter.format(dt);
    } catch (_) {
      return DateFormat('M/d').format(dt);
    }
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClose,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              hintText: '내용, 태그, 양식장, 작성자 검색',
              hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
              prefixIconConstraints: const BoxConstraints(minWidth: 36),
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) => value.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        tooltip: '지우기',
                        icon: const Icon(Icons.cancel, size: 16, color: AppColors.textMuted),
                        onPressed: () {
                          controller.clear();
                          onChanged('');
                        },
                      ),
              ),
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(vertical: 9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
        ),
        TextButton(
          onPressed: onClose,
          child: const Text('취소', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        ),
      ],
    );
  }
}
