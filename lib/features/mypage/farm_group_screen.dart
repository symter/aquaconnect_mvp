import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/data_providers.dart';
import '../../core/providers/farm_group_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/farm.dart';
import '../../data/models/farm_group.dart';

/// "마이페이지 > 양식장 그룹 관리" — the institute builds its own groups
/// (e.g. by 권역 or 담당 구역) and Home's 그룹별 sort lists the farms under
/// them. A farm belongs to at most one group.
class FarmGroupScreen extends ConsumerWidget {
  const FarmGroupScreen({super.key});

  Future<void> _openEditor(BuildContext context, List<Farm> farms, List<FarmGroup> groups, [FarmGroup? existing]) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _GroupEditorSheet(farms: farms, groups: groups, existing: existing),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, FarmGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('그룹 삭제'),
        content: Text("'${group.name}' 그룹을 삭제할까요? 양식장은 삭제되지 않고 '그룹 미지정'으로 이동해요."),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('삭제', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) await ref.read(farmListPrefsProvider.notifier).deleteGroup(group.id);
  }

  /// One group per 시·군·구 found in the farms' addresses, skipping regions
  /// that already have a group of that name.
  Future<void> _createByRegion(BuildContext context, WidgetRef ref, List<Farm> farms, List<FarmGroup> groups) async {
    final byRegion = <String, List<String>>{};
    for (final f in farms) {
      byRegion.putIfAbsent(regionOf(f), () => []).add(f.id);
    }
    final taken = groups.map((g) => g.name).toSet();
    final notifier = ref.read(farmListPrefsProvider.notifier);
    var created = 0;
    for (final e in byRegion.entries) {
      if (taken.contains(e.key)) continue;
      await notifier.saveGroup(FarmGroup(id: 'g-${DateTime.now().microsecondsSinceEpoch}-$created', name: e.key, farmIds: e.value));
      created++;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(created == 0 ? '새로 만들 지역 그룹이 없어요.' : '지역별 그룹 $created개를 만들었어요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farms = ref.watch(farmsProvider).valueOrNull ?? const <Farm>[];
    final prefsAsync = ref.watch(farmListPrefsProvider);
    final groups = prefsAsync.valueOrNull?.groups ?? const <FarmGroup>[];
    final farmById = {for (final f in farms) f.id: f};

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.brandDark,
        title: const Text('양식장 그룹 관리', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.brandDark)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.brand,
        onPressed: farms.isEmpty ? null : () => _openEditor(context, farms, groups),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
        children: [
          const Text(
            "원하는 기준으로 양식장을 묶어 두면 홈의 '그룹별' 정렬에서 그룹마다 모아 볼 수 있어요. 이 기기에 저장돼요.",
            style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.5),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: farms.isEmpty ? null : () => _createByRegion(context, ref, farms, groups),
            icon: const Icon(Icons.map_outlined, size: 16),
            label: const Text('지역(시·군)별로 그룹 자동 만들기'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.brand, side: const BorderSide(color: AppColors.brand)),
          ),
          const SizedBox(height: 16),
          if (groups.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text('만든 그룹이 없어요.\n오른쪽 아래 + 버튼으로 그룹을 만들어 보세요.',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            ),
          for (final g in groups) ...[
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                onTap: () => _openEditor(context, farms, groups, g),
                title: Text(g.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    g.farmIds.isEmpty
                        ? '양식장 없음'
                        : '${g.farmIds.length}곳 · ${g.farmIds.map((id) => farmById[id]?.name).whereType<String>().join(', ')}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
                trailing: IconButton(
                  tooltip: '삭제',
                  icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.textMuted),
                  onPressed: () => _confirmDelete(context, ref, g),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _GroupEditorSheet extends ConsumerStatefulWidget {
  const _GroupEditorSheet({required this.farms, required this.groups, this.existing});

  final List<Farm> farms;
  final List<FarmGroup> groups;
  final FarmGroup? existing;

  @override
  ConsumerState<_GroupEditorSheet> createState() => _GroupEditorSheetState();
}

class _GroupEditorSheetState extends ConsumerState<_GroupEditorSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.existing?.name ?? '');
  late final Set<String> _selected = {...?widget.existing?.farmIds};
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// The other group a farm currently sits in, if any.
  String? _otherGroupOf(String farmId) {
    for (final g in widget.groups) {
      if (g.id != widget.existing?.id && g.farmIds.contains(farmId)) return g.name;
    }
    return null;
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '그룹 이름을 입력해주세요.');
      return;
    }
    if (widget.groups.any((g) => g.id != widget.existing?.id && g.name == name)) {
      setState(() => _error = '같은 이름의 그룹이 이미 있어요.');
      return;
    }
    final group = FarmGroup(
      id: widget.existing?.id ?? 'g-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      farmIds: widget.farms.where((f) => _selected.contains(f.id)).map((f) => f.id).toList(),
    );
    await ref.read(farmListPrefsProvider.notifier).saveGroup(group);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                Text(widget.existing == null ? '그룹 만들기' : '그룹 수정',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.brandDark)),
                const SizedBox(height: 12),
                TextField(
                  controller: _name,
                  decoration: InputDecoration(
                    hintText: '그룹 이름 (예: 완도 A권역)',
                    errorText: _error,
                    filled: true,
                    fillColor: AppColors.background,
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  onChanged: (_) => setState(() => _error = null),
                ),
                const SizedBox(height: 12),
                Text('양식장 선택 ${_selected.length}곳',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final f in widget.farms)
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _selected.contains(f.id),
                          onChanged: (v) => setState(() => v == true ? _selected.add(f.id) : _selected.remove(f.id)),
                          title: Text(f.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            [regionOf(f), if (_otherGroupOf(f.id) != null) "'${_otherGroupOf(f.id)}'에서 이동"].join(' · '),
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('저장', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
