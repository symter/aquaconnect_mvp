import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/farm_group.dart';

/// Home list preferences — the chosen sort and the institute's custom farm
/// groups. Per-device, persisted locally like [DigestSettingsStore]: there is
/// no groups API yet, so groups are not shared between devices or members.
class FarmListPrefs {
  const FarmListPrefs({this.sort = FarmSort.risk, this.groups = const []});

  final FarmSort sort;
  final List<FarmGroup> groups;

  FarmListPrefs copyWith({FarmSort? sort, List<FarmGroup>? groups}) =>
      FarmListPrefs(sort: sort ?? this.sort, groups: groups ?? this.groups);
}

class FarmGroupStore {
  static const _sortKey = 'aquaconnect.farm_list.sort';
  static const _groupsKey = 'aquaconnect.farm_list.groups';

  Future<FarmListPrefs> read() async {
    final prefs = await SharedPreferences.getInstance();
    var groups = <FarmGroup>[];
    try {
      final raw = prefs.getString(_groupsKey);
      if (raw != null) {
        groups = (jsonDecode(raw) as List<dynamic>).map((e) => FarmGroup.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {
      // Corrupt value — start empty rather than break Home.
    }
    return FarmListPrefs(sort: FarmSort.fromKey(prefs.getString(_sortKey)), groups: groups);
  }

  Future<void> write(FarmListPrefs value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sortKey, value.sort.name);
    await prefs.setString(_groupsKey, jsonEncode(value.groups.map((g) => g.toJson()).toList()));
  }
}
