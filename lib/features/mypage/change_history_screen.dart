import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/chips.dart';
import '../../data/models/audit_log.dart';

/// 마이페이지 > 메모·변경 이력 (원장 only) — every memo's history (등록·수정·
/// 완료·댓글), 삭제 기록 (what was in a memo or 댓글 before it was deleted)
/// and member / farm / 관리원 changes, newest first, grouped by day. The
/// server keeps 3 months.
class ChangeHistoryScreen extends ConsumerStatefulWidget {
  const ChangeHistoryScreen({super.key});

  @override
  ConsumerState<ChangeHistoryScreen> createState() => _ChangeHistoryScreenState();
}

/// The chip row: everything, one kind, or only deletions.
enum _Filter {
  all('전체'),
  memo('메모'),
  deleted('삭제 기록'),
  farm('양식장'),
  member('구성원'),
  organization('관리원');

  const _Filter(this.label);
  final String label;

  AuditEntityType? get type => switch (this) {
        _Filter.memo => AuditEntityType.memo,
        _Filter.farm => AuditEntityType.farm,
        _Filter.member => AuditEntityType.member,
        _Filter.organization => AuditEntityType.organization,
        _ => null,
      };
}

class _ChangeHistoryScreenState extends ConsumerState<ChangeHistoryScreen> {
  _Filter _filter = _Filter.all;
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  String _search = '';
  final List<AuditLogEntry> _items = [];
  String? _nextBefore;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<AuditLogPage> _fetch({String? before}) => ref.read(orgRepositoryProvider).listAuditLogs(
        type: _filter.type,
        deletedOnly: _filter == _Filter.deleted,
        search: _search,
        before: before,
      );

  Future<void> _reload() async {
    // A newer filter/search wins over a slower earlier request.
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _fetch();
      if (!mounted || request != _request) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _nextBefore = page.nextBefore;
        _loading = false;
      });
    } catch (e) {
      if (mounted && request == _request) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_nextBefore == null || _loadingMore) return;
    final request = _request;
    setState(() => _loadingMore = true);
    try {
      final page = await _fetch(before: _nextBefore);
      if (!mounted || request != _request) return;
      setState(() {
        _items.addAll(page.items);
        _nextBefore = page.nextBefore;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('더 불러오지 못했어요: $e')));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _setFilter(_Filter filter) {
    if (filter == _filter) return;
    setState(() => _filter = filter);
    _reload();
  }

  void _onSearchChanged(String value) {
    setState(() {}); // the clear (×) button follows the text
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () => _applySearch(value));
  }

  void _applySearch(String value) {
    _searchDebounce?.cancel();
    final next = value.trim();
    if (next == _search) return;
    setState(() => _search = next);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.brandDark,
        title: const Text('메모·변경 이력', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.brandDark)),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  onSubmitted: _applySearch,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '양식장, 사람, 메모 내용으로 찾기',
                    hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search, size: 19, color: AppColors.textMuted),
                    suffixIcon: _searchCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '지우기',
                            icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                            onPressed: () {
                              _searchCtrl.clear();
                              _applySearch('');
                            },
                          ),
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final f in _Filter.values) ...[
                        if (f != _Filter.all) const SizedBox(width: 6),
                        FilterPillChip(
                          label: f.label,
                          selected: _filter == f,
                          onTap: () => _setFilter(f),
                          selectedColor: f == _Filter.deleted ? AppColors.danger : AppColors.brand,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  String get _emptyText {
    if (_search.isNotEmpty) return "'$_search'에 맞는 기록이 없어요";
    return switch (_filter) {
      _Filter.deleted => '최근 3개월 동안 삭제된 메모·댓글이 없어요',
      _Filter.memo => '최근 3개월 동안의 메모 이력이 없어요',
      _ => '최근 3개월 동안의 변경 이력이 없어요',
    };
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('이력을 불러오지 못했어요.\n$_error',
                textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
            TextButton(onPressed: _reload, child: const Text('다시 시도')),
          ],
        ),
      );
    }

    final days = <String, List<AuditLogEntry>>{};
    for (final e in _items) {
      days.putIfAbsent(_dayLabel(e.createdAt), () => []).add(e);
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        children: [
          if (_filter == _Filter.deleted && _items.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                '지워진 메모와 댓글은 앱에서 다시 볼 수 없어서, 지우기 전 내용을 여기에 남겨 두어요.',
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.4),
              ),
            ),
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 80),
              child: Column(
                children: [
                  const Icon(Icons.history, size: 40, color: AppColors.textFaint),
                  const SizedBox(height: 12),
                  Text(_emptyText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                ],
              ),
            ),
          for (final day in days.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
              child: Text(day.key, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
            ),
            for (final e in day.value) ...[
              _EntryCard(key: ValueKey(e.id), entry: e),
              const SizedBox(height: 8),
            ],
          ],
          if (_nextBefore != null)
            Center(
              child: TextButton(
                onPressed: _loadingMore ? null : _loadMore,
                child: Text(_loadingMore ? '불러오는 중…' : '더 보기',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.brand)),
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            '메모·변경 이력은 3개월 동안 보관되고, 그 뒤에는 자동으로 삭제됩니다.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  static String _dayLabel(DateTime at) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    if (day == today) return '오늘';
    if (day == today.subtract(const Duration(days: 1))) return '어제';
    return DateFormat('M월 d일 EEEE', 'ko_KR').format(at);
  }
}

class _EntryCard extends StatefulWidget {
  const _EntryCard({super.key, required this.entry});

  final AuditLogEntry entry;

  @override
  State<_EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends State<_EntryCard> {
  bool _expanded = false;

  AuditLogEntry get entry => widget.entry;

  /// A memo that still exists can be opened from its entry.
  bool get _canOpenMemo => entry.entityType == AuditEntityType.memo && entry.entityId != null && entry.action != 'delete';

  /// Long memo text is clamped until the card is tapped.
  bool get _hasLongText => entry.changes.any((c) => c.from.length > 120 || c.to.length > 120 || '${c.from}${c.to}'.contains('\n'));

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (entry.entityType) {
      AuditEntityType.memo when entry.isDeletion => (Icons.delete_outline, AppColors.danger),
      AuditEntityType.memo when entry.action.startsWith('comment') => (Icons.chat_bubble_outline, AppColors.brand),
      AuditEntityType.memo => (Icons.sticky_note_2_outlined, AppColors.brand),
      AuditEntityType.member => (Icons.person_outline, AppColors.brand),
      AuditEntityType.farm => (Icons.home_work_outlined, AppColors.good),
      AuditEntityType.organization => (Icons.local_hospital_outlined, AppColors.warningDark),
    };
    final isRemoval = entry.isDeletion || entry.action == 'deactivate';
    final isMemo = entry.entityType == AuditEntityType.memo;
    final actor = entry.actorName.isEmpty ? '' : (isMemo ? ' · ${entry.actorName}' : ' · ${entry.actorName}님이 변경');

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _hasLongText ? () => setState(() => _expanded = !_expanded) : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: isRemoval && isMemo ? AppColors.danger.withValues(alpha: 0.35) : AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.actionLabel,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: isRemoval ? AppColors.danger : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(DateFormat('HH:mm').format(entry.createdAt),
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: entry.entityName, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        TextSpan(text: actor),
                      ]),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    for (final c in entry.changes) ...[
                      const SizedBox(height: 6),
                      if (isMemo && c.isSnapshot)
                        _SnapshotLine(change: c, removed: entry.isDeletion, expanded: _expanded)
                      else
                        _ChangeLine(change: c, expanded: !isMemo || _expanded),
                    ],
                    if (_hasLongText || _canOpenMemo)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            if (_hasLongText)
                              Text(_expanded ? '접기' : '전체 내용 보기',
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                            const Spacer(),
                            if (_canOpenMemo)
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  minimumSize: const Size(0, 30),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () => context.go('/memo?memo=${entry.entityId}&detail=1'),
                                child: const Text('메모 보기 ›',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.brand)),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A memo entry's "내용  …" line: what was added, or (for a deletion) what
/// was there before it was removed.
class _SnapshotLine extends StatelessWidget {
  const _SnapshotLine({required this.change, required this.removed, required this.expanded});

  final AuditChange change;
  final bool removed;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final value = change.to.isNotEmpty ? change.to : change.from;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: removed ? AppColors.dangerTint : AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Text(change.label,
                style: const TextStyle(fontSize: 12, height: 1.4, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: expanded ? null : 3,
              overflow: expanded ? null : TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangeLine extends StatelessWidget {
  const _ChangeLine({required this.change, required this.expanded});

  final AuditChange change;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    String show(String v) => v.isEmpty ? '(없음)' : v;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: '${change.label}  ', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          TextSpan(
            text: show(change.from),
            style: const TextStyle(color: AppColors.textMuted, decoration: TextDecoration.lineThrough),
          ),
          const TextSpan(text: '  →  ', style: TextStyle(color: AppColors.textMuted)),
          TextSpan(text: show(change.to), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ]),
        maxLines: expanded ? null : 6,
        overflow: expanded ? null : TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, height: 1.4),
      ),
    );
  }
}
