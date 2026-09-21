import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/data_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/stat_grid.dart';
import '../../data/models/disease_info.dart';
import '../../data/models/ocean_reading.dart';
import '../../data/services/ocean_service.dart';
import '../../data/services/ocean_station_preference_store.dart';

class InfoScreen extends ConsumerStatefulWidget {
  const InfoScreen({super.key});

  @override
  ConsumerState<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends ConsumerState<InfoScreen> {
  String? _stationCode;
  String? _stationName;
  bool _initializedFromPreference = false;
  final Set<DiseaseInfoScope> _scopeFilter = {DiseaseInfoScope.domestic};
  String? _speciesFilter = '넙치';

  void _selectStation(OceanStation station) {
    setState(() {
      _stationCode = station.code;
      _stationName = station.name;
    });
    ref.read(selectedOceanStationProvider.notifier).select(
          OceanStationSelection(code: station.code, name: station.name),
        );
  }

  @override
  Widget build(BuildContext context) {
    final oceanService = ref.watch(oceanServiceProvider);
    final diseaseAsync = ref.watch(diseaseInfoProvider);
    final stationsAsync = ref.watch(oceanStationsProvider);

    final stations = stationsAsync.valueOrNull;
    if (stations != null && stations.isNotEmpty && !_initializedFromPreference) {
      final preferred = ref.read(selectedOceanStationProvider).valueOrNull;
      var initial = stations.first;
      if (preferred != null) {
        for (final s in stations) {
          if (s.code == preferred.code) {
            initial = s;
            break;
          }
        }
      }
      _stationCode = initial.code;
      _stationName = initial.name;
      _initializedFromPreference = true;
    }

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
                children: const [
                  Text('정보', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.brandDark)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  _OceanSection(
                    stationsAsync: stationsAsync,
                    stationCode: _stationCode,
                    stationName: _stationName,
                    oceanService: oceanService,
                    onSelectStation: _selectStation,
                  ),
                  const SizedBox(height: 18),
                  const Text('수산질병 정보', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _FilterToggle(
                        label: '전체',
                        selected: _scopeFilter.isEmpty && _speciesFilter == null,
                        onTap: () => setState(() {
                          _scopeFilter.clear();
                          _speciesFilter = null;
                        }),
                      ),
                      _FilterToggle(
                        label: '국내',
                        selected: _scopeFilter.contains(DiseaseInfoScope.domestic),
                        onTap: () => setState(() => _toggleScope(DiseaseInfoScope.domestic)),
                      ),
                      _FilterToggle(
                        label: '해외',
                        selected: _scopeFilter.contains(DiseaseInfoScope.overseas),
                        onTap: () => setState(() => _toggleScope(DiseaseInfoScope.overseas)),
                      ),
                      _FilterToggle(
                        label: '넙치',
                        selected: _speciesFilter == '넙치',
                        onTap: () => setState(() => _speciesFilter = _speciesFilter == '넙치' ? null : '넙치'),
                      ),
                      _FilterToggle(
                        label: '새우',
                        selected: _speciesFilter == '새우',
                        onTap: () => setState(() => _speciesFilter = _speciesFilter == '새우' ? null : '새우'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('여러 항목을 함께 선택할 수 있어요 (예: 국내 + 넙치) · 전체를 누르면 초기화',
                      style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  const SizedBox(height: 10),
                  diseaseAsync.when(
                    data: (items) {
                      final filtered = items.where((d) {
                        final scopeOk = _scopeFilter.isEmpty || _scopeFilter.contains(d.scope);
                        final speciesOk = _speciesFilter == null || d.species == _speciesFilter;
                        return scopeOk && speciesOk;
                      }).toList();
                      if (filtered.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text('조건에 맞는 정보가 없습니다.', style: TextStyle(color: AppColors.textMuted)),
                        );
                      }
                      return Column(
                        children: [
                          for (final d in filtered) ...[
                            _DiseaseInfoCard(info: d),
                            const SizedBox(height: 8),
                          ],
                        ],
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('불러오기 실패: $e'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleScope(DiseaseInfoScope scope) {
    if (_scopeFilter.contains(scope)) {
      _scopeFilter.remove(scope);
    } else {
      _scopeFilter.add(scope);
    }
  }
}

class _OceanSection extends StatelessWidget {
  const _OceanSection({
    required this.stationsAsync,
    required this.stationCode,
    required this.stationName,
    required this.oceanService,
    required this.onSelectStation,
  });

  final AsyncValue<List<OceanStation>> stationsAsync;
  final String? stationCode;
  final String? stationName;
  final OceanService oceanService;
  final ValueChanged<OceanStation> onSelectStation;

  @override
  Widget build(BuildContext context) {
    return stationsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
        child: Text('관측소 목록을 불러오지 못했습니다.\n$e', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      ),
      data: (stations) {
        if (stations.isEmpty || stationCode == null || stationName == null) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
            child: const Text('선택 가능한 관측소가 없습니다.', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('해양환경 데이터',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                PopupMenuButton<String>(
                  initialValue: stationCode,
                  onSelected: (code) => onSelectStation(stations.firstWhere((s) => s.code == code)),
                  itemBuilder: (context) =>
                      stations.map((s) => PopupMenuItem(value: s.code, child: Text(s.name))).toList(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: AppColors.brandTint, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(stationName!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.brand)),
                        const Icon(Icons.expand_more, size: 14, color: AppColors.brand),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text('여러 해역의 중층·저층 수온을 확인할 수 있어요 — 위 칩을 눌러 전환 (마이페이지에서도 선택 가능)',
                style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
            const SizedBox(height: 10),
            FutureBuilder<OceanSnapshot>(
              key: ValueKey(stationCode),
              future: oceanService.fetchSnapshot(stationCode: stationCode!, stationName: stationName!, region: stationName!),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
                    child: Text('해양환경 데이터를 불러오지 못했습니다.\n${snapshot.error ?? ''}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  );
                }
                final ocean = snapshot.data!;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OceanStatGrid(snapshot: ocean),
                      const SizedBox(height: 12),
                      Text('일별 수온 (℃) · 최근 ${ocean.sevenDayTemps.length}일',
                          style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                      const SizedBox(height: 4),
                      TempSparkline(values: ocean.sevenDayTemps),
                      const SizedBox(height: 2),
                      ChartDayLabels(labels: ocean.sevenDayLabels),
                      const SizedBox(height: 10),
                      Text(
                        ocean.hasTrendHistory ? '출처 · ${ocean.source}' : '출처 · ${ocean.source} · 실시간 값만 제공',
                        style: const TextStyle(fontSize: 9.5, color: Color(0xFF8FA0B5)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _FilterToggle extends StatelessWidget {
  const _FilterToggle({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.fromLTRB(selected ? 10 : 12, 5, 12, 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.brand : AppColors.surface,
          border: selected ? null : Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.check, size: 10, color: Colors.white),
            ),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _DiseaseInfoCard extends StatelessWidget {
  const _DiseaseInfoCard({required this.info});

  final DiseaseInfo info;

  @override
  Widget build(BuildContext context) {
    final isDomestic = info.scope == DiseaseInfoScope.domestic;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isDomestic ? AppColors.goodTint : AppColors.neutralChip,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              info.scope.label,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: isDomestic ? AppColors.good : AppColors.neutralIcon),
            ),
          ),
          const SizedBox(height: 4),
          Text(info.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text('${DateFormat('M/d').format(info.publishedAt)} · ${info.source}',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
