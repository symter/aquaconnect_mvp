import 'package:aquaconnect_mvp/core/providers/farm_group_provider.dart';
import 'package:aquaconnect_mvp/data/models/farm.dart';
import 'package:aquaconnect_mvp/data/models/farm_group.dart';
import 'package:aquaconnect_mvp/data/models/risk_level.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Farm farm(String id, String address) => Farm(
      id: id,
      orgId: 'o',
      name: id,
      region: '',
      address: address,
      nearestStationCode: '',
      nearestStationName: '',
      riskLevel: RiskLevel.good,
      headline: '',
      waterTemp: 0,
      lastVisitDays: 0,
    );

void main() {
  test('regionOf picks the 시·군·구 word', () {
    expect(regionOf(farm('a', '전남 완도군 노화읍 1')), '완도군');
    expect(regionOf(farm('a', '경남 통영시 도남동')), '통영시');
    expect(regionOf(farm('a', '')), '지역 미확인');
  });

  test('a farm can only be in one group, and groups persist', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(farmListPrefsProvider.notifier);
    await c.read(farmListPrefsProvider.future);
    await n.saveGroup(const FarmGroup(id: '1', name: 'A', farmIds: ['f1', 'f2']));
    await n.saveGroup(const FarmGroup(id: '2', name: 'B', farmIds: ['f2']));
    final groups = c.read(farmListPrefsProvider).value!.groups;
    expect(groups.firstWhere((g) => g.id == '1').farmIds, ['f1']);
    expect(groups.firstWhere((g) => g.id == '2').farmIds, ['f2']);
    await n.setSort(FarmSort.group);

    final c2 = ProviderContainer();
    addTearDown(c2.dispose);
    final reloaded = await c2.read(farmListPrefsProvider.future);
    expect(reloaded.sort, FarmSort.group);
    expect(reloaded.groups.length, 2);
  });
}
