import 'farm.dart';

/// How Home orders / sections the 담당 양식장 list.
/// 지역별 is the default; the order here is also the order in the sort menu.
enum FarmSort {
  region,
  group,
  risk;

  String get label => switch (this) {
        FarmSort.risk => '위험도순',
        FarmSort.region => '지역별',
        FarmSort.group => '그룹별',
      };

  static FarmSort fromKey(String? key) => FarmSort.values.firstWhere((s) => s.name == key, orElse: () => FarmSort.region);
}

/// A named set of farms the institute built itself ("완도 A권역" …). A farm
/// belongs to at most one group, so the grouped list has no duplicates.
class FarmGroup {
  const FarmGroup({required this.id, required this.name, this.farmIds = const []});

  final String id;
  final String name;
  final List<String> farmIds;

  FarmGroup copyWith({String? name, List<String>? farmIds}) =>
      FarmGroup(id: id, name: name ?? this.name, farmIds: farmIds ?? this.farmIds);

  factory FarmGroup.fromJson(Map<String, dynamic> json) => FarmGroup(
        id: json['id'] as String,
        name: json['name'] as String,
        farmIds: (json['farmIds'] as List<dynamic>? ?? const []).cast<String>(),
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'farmIds': farmIds};
}

/// 시·군·구 of a farm's 주소 for the 지역별 sort — "전남 완도군 노화읍 …" →
/// "완도군". Falls back to the first word, then "지역 미확인".
String regionOf(Farm farm) {
  final words = farm.address.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '지역 미확인';
  if (words.length > 1 && RegExp(r'[시군구]$').hasMatch(words[1])) return words[1];
  return words.first;
}
