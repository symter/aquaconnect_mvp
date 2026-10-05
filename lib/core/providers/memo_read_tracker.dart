import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/memo_repository.dart';
import 'repository_providers.dart';

/// Collects the memos that came on screen and reports them as read in one
/// batched request, instead of one call per [MemoCard].
final memoReadTrackerProvider = Provider<MemoReadTracker>((ref) {
  final tracker = MemoReadTracker(ref.watch(memoRepositoryProvider));
  ref.onDispose(tracker.dispose);
  return tracker;
});

class MemoReadTracker {
  MemoReadTracker(this._repository, {this.delay = const Duration(milliseconds: 800)});

  final MemoRepository _repository;
  final Duration delay;

  final _pending = <String>{};
  // Already sent this session — the next poll may still say unread until the
  // server has caught up, and that must not resend.
  final _sent = <String>{};
  Timer? _timer;

  void seen(String memoId) {
    if (_sent.contains(memoId) || !_pending.add(memoId)) return;
    _timer ??= Timer(delay, _flush);
  }

  Future<void> _flush() async {
    _timer = null;
    final ids = _pending.toList();
    _pending.clear();
    _sent.addAll(ids);
    try {
      await _repository.markRead(ids);
    } catch (_) {
      // Best-effort: let these be retried the next time they're on screen.
      _sent.removeAll(ids);
    }
  }

  void dispose() => _timer?.cancel();
}
