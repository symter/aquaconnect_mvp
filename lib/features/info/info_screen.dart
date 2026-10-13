import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/data_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/memo_composer_bar.dart';
import '../../core/widgets/ocean_data_times_dialog.dart';
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
  final Set<DiseaseInfoScope> _scopeFilter = {};
  String? _speciesFilter;

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
              width: double.infinity,
              color: AppColors.background,
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
            const MemoComposerBar(confirmOnSave: true),
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

class _OceanSection extends StatefulWidget {
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
  State<_OceanSection> createState() => _OceanSectionState();
}

class _OceanSectionState extends State<_OceanSection> {
  Future<OceanSnapshot>? _future;
  String? _futureStationCode;

  /// The last snapshot loaded for the current station, kept for the ⓘ
  /// button while a refresh is in flight.
  OceanSnapshot? _latest;

  /// Created once per station (and on refresh) instead of on every build,
  /// so rebuilds don't refetch.
  Future<OceanSnapshot>? _snapshotFuture() {
    if (widget.stationCode == null || widget.stationName == null) return null;
    if (_future == null || _futureStationCode != widget.stationCode) {
      _latest = null;
      _load(refresh: false);
    }
    return _future;
  }

  void _load({required bool refresh}) {
    final code = widget.stationCode!;
    final name = widget.stationName!;
    _futureStationCode = code;
    _future = widget.oceanService
        .fetchSnapshot(stationCode: code, stationName: name, region: name, refresh: refresh)
        .then((snapshot) {
      if (mounted && _futureStationCode == code) setState(() => _latest = snapshot);
      return snapshot;
    });
  }

  void _refresh() => setState(() => _load(refresh: true));

  @override
  Widget build(BuildContext context) {
    return widget.stationsAsync.when(
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
        final future = _snapshotFuture();
        if (stations.isEmpty || future == null) {
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
              children: [
                const Text('해양환경 데이터',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                _HeaderIconButton(icon: Icons.refresh, tooltip: '새로고침', onPressed: _refresh),
                _HeaderIconButton(
                  icon: Icons.info_outline,
                  tooltip: '최근 관측 시각',
                  onPressed: _latest == null ? null : () => showOceanDataTimesDialog(context, _latest!),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  initialValue: widget.stationCode,
                  onSelected: (code) => widget.onSelectStation(stations.firstWhere((s) => s.code == code)),
                  itemBuilder: (context) =>
                      stations.map((s) => PopupMenuItem(value: s.code, child: Text(s.name))).toList(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: AppColors.brandTint, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.stationName!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.brand)),
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
              future: future,
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
                final quality = ocean.waterQuality;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OceanStatGrid(snapshot: ocean),
                      if (quality != null) ...[
                        const SizedBox(height: 12),
                        Text('수질 상세 · ${quality.pointName} (${DateFormat('yyyy.M.d').format(quality.observedAt)} 조사)',
                            style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                        const SizedBox(height: 6),
                        WaterQualityGrid(quality: quality),
                        const SizedBox(height: 4),
                        const Text('저층 기준 · 염도 psu, 용존산소·COD·질소·인·부유물질 mg/L, 클로로필a µg/L',
                            style: TextStyle(fontSize: 9.5, color: AppColors.textMuted)),
                      ],
                      const SizedBox(height: 10),
                      Text('출처 · ${ocean.source}', style: const TextStyle(fontSize: 9.5, color: Color(0xFF8FA0B5))),
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

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      color: AppColors.textTertiary,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: onPressed,
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
