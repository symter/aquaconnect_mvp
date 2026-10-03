import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/farm_group.dart';
import '../../data/services/farm_group_store.dart';

final farmGroupStoreProvider = Provider<FarmGroupStore>((ref) => FarmGroupStore());

final farmListPrefsProvider = AsyncNotifierProvider<FarmListPrefsNotifier, FarmListPrefs>(FarmListPrefsNotifier.new);

class FarmListPrefsNotifier extends AsyncNotifier<FarmListPrefs> {
  // Serializes updates so quick successive edits can't clobber each other.
  Future<void> _writeQueue = Future.value();

  @override
  Future<FarmListPrefs> build() => ref.watch(farmGroupStoreProvider).read();

  Future<void> _update(FarmListPrefs Function(FarmListPrefs) transform) {
    final result = _writeQueue.then((_) async {
      final current = state.valueOrNull ?? await ref.read(farmGroupStoreProvider).read();
      final next = transform(current);
      await ref.read(farmGroupStoreProvider).write(next);
      state = AsyncValue.data(next);
    });
    _writeQueue = result.catchError((_) {});
    return result;
  }

  Future<void> setSort(FarmSort sort) => _update((p) => p.copyWith(sort: sort));

  /// Creates a group, or replaces the one with the same id. A farm can only be
  /// in one group, so its ids are removed from every other group.
  Future<void> saveGroup(FarmGroup group) => _update((p) {
        final others = [
          for (final g in p.groups)
            if (g.id != group.id) g.copyWith(farmIds: g.farmIds.where((id) => !group.farmIds.contains(id)).toList()),
        ];
        final exists = p.groups.any((g) => g.id == group.id);
        final next = exists
            ? [
                for (final g in p.groups)
                  if (g.id == group.id) group else others.firstWhere((o) => o.id == g.id),
              ]
            : [...others, group];
        return p.copyWith(groups: next);
      });

  Future<void> deleteGroup(String id) => _update((p) => p.copyWith(groups: p.groups.where((g) => g.id != id).toList()));
}
