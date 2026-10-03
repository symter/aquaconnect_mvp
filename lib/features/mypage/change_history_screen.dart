import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/chips.dart';
import '../../data/models/audit_log.dart';

/// 마이페이지 > 변경 이력 — who changed which member, farm or 관리원 data,
/// newest first, grouped by day. The server keeps 3 months.
class ChangeHistoryScreen extends ConsumerStatefulWidget {
  const ChangeHistoryScreen({super.key});

  @override
  ConsumerState<ChangeHistoryScreen> createState() => _ChangeHistoryScreenState();
}

class _ChangeHistoryScreenState extends ConsumerState<ChangeHistoryScreen> {
  AuditEntityType? _type;
  final List<AuditLogEntry> _items = [];
  String? _nextBefore;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref.read(orgRepositoryProvider).listAuditLogs(type: _type);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _nextBefore = page.nextBefore;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_nextBefore == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref.read(orgRepositoryProvider).listAuditLogs(type: _type, before: _nextBefore);
      if (!mounted) return;
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

  void _setType(AuditEntityType? type) {
    if (type == _type) return;
    setState(() => _type = type);
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
        title: const Text('변경 이력', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.brandDark)),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  FilterPillChip(label: '전체', selected: _type == null, onTap: () => _setType(null)),
                  for (final t in AuditEntityType.values) ...[
                    const SizedBox(width: 6),
                    FilterPillChip(label: t.label, selected: _type == t, onTap: () => _setType(t)),
                  ],
                ],
              ),
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('변경 이력을 불러오지 못했어요.\n$_error',
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
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Column(
                children: [
                  Icon(Icons.history, size: 40, color: AppColors.textFaint),
                  SizedBox(height: 12),
                  Text('최근 3개월 동안의 변경 이력이 없어요',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                ],
              ),
            ),
          for (final day in days.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
              child: Text(day.key, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
            ),
            for (final e in day.value) ...[
              _EntryCard(entry: e),
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
            '변경 이력은 3개월 동안 보관되고, 그 뒤에는 자동으로 삭제됩니다.',
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

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final AuditLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (entry.entityType) {
      AuditEntityType.member => (Icons.person_outline, AppColors.brand),
      AuditEntityType.farm => (Icons.home_work_outlined, AppColors.good),
      AuditEntityType.organization => (Icons.local_hospital_outlined, AppColors.warningDark),
    };
    final isRemoval = entry.action == 'delete' || entry.action == 'deactivate';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
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
                    TextSpan(text: entry.actorName.isEmpty ? '' : ' · ${entry.actorName}님이 변경'),
                  ]),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                for (final c in entry.changes) ...[
                  const SizedBox(height: 6),
                  _ChangeLine(change: c),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangeLine extends StatelessWidget {
  const _ChangeLine({required this.change});

  final AuditChange change;

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
        style: const TextStyle(fontSize: 12, height: 1.4),
      ),
    );
  }
}
