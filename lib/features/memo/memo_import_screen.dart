import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/data_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/korean_search.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/farm_search_field.dart';
import '../../data/models/farm.dart';
import '../../data/models/memo_import.dart';
import '../../data/services/file_transfer.dart';

/// 메모 일괄 업로드 (symterAI memos/import): pick a farm and an Excel CSV or
/// 메모장 .txt, check what was read (and what was skipped, and why), then
/// upload. Each memo is filed under the date written in the file.
class MemoImportScreen extends ConsumerStatefulWidget {
  const MemoImportScreen({super.key, this.farmId});

  /// Preselected farm (opened from a farm's screen).
  final String? farmId;

  @override
  ConsumerState<MemoImportScreen> createState() => _MemoImportScreenState();
}

class _MemoImportScreenState extends ConsumerState<MemoImportScreen> {
  late String? _farmId = widget.farmId;
  PickedFile? _file;
  MemoImportResult? _preview;
  bool _busy = false;
  String? _error;

  Future<void> _pickFile() async {
    final files = await pickFiles();
    if (files.isEmpty) return;
    final f = files.first;
    if (!RegExp(r'\.(csv|txt)$', caseSensitive: false).hasMatch(f.name)) {
      setState(() => _error = 'CSV(.csv) 또는 메모장(.txt) 파일을 골라 주세요. 엑셀은 "다른 이름으로 저장 → CSV"로 저장하면 돼요.');
      return;
    }
    setState(() {
      _file = f;
      _preview = null;
      _error = null;
    });
    await _readPreview();
  }

  Future<void> _readPreview() async {
    final farmId = _farmId;
    final file = _file;
    if (farmId == null || file == null) return;
    setState(() => _busy = true);
    try {
      final r = await ref.read(memoRepositoryProvider).importMemos(farmId: farmId, fileName: file.name, bytes: file.bytes, dryRun: true);
      if (mounted) setState(() => _preview = r);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload() async {
    final farmId = _farmId!;
    final file = _file!;
    setState(() => _busy = true);
    try {
      final r = await ref.read(memoRepositoryProvider).importMemos(farmId: farmId, fileName: file.name, bytes: file.bytes);
      ref.invalidate(memosProvider(null));
      ref.invalidate(memosProvider(farmId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('메모 ${r.created}건을 올렸어요.')));
      Navigator.of(context).maybePop();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickFarm(List<Farm> farms) async {
    var query = '';
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheet).viewInsets.bottom),
          child: SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(sheet).size.height * 0.7),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
                    child: Text('양식장 선택', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    child: FarmSearchField(fillColor: AppColors.background, onChanged: (q) => setSheet(() => query = q)),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final f in searchFarms(farms, query))
                          ListTile(
                            dense: true,
                            title: Text(f.name, style: const TextStyle(fontSize: 14)),
                            subtitle: f.address.isEmpty ? null : Text(f.address, maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: f.id == _farmId ? const Icon(Icons.check, size: 18, color: AppColors.brand) : null,
                            onTap: () => Navigator.of(sheet).pop(f.id),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (picked == null || picked == _farmId) return;
    setState(() {
      _farmId = picked;
      _preview = null;
    });
    await _readPreview();
  }

  @override
  Widget build(BuildContext context) {
    final farms = ref.watch(farmsProvider).valueOrNull ?? const <Farm>[];
    final farm = farms.where((f) => f.id == _farmId).firstOrNull;
    final p = _preview;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.brandDark,
        title: const Text('메모 일괄 업로드', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.brandDark)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: AppColors.brandTintStrong, border: Border.all(color: AppColors.brandTintBorder), borderRadius: BorderRadius.circular(14)),
                  child: const Text(
                    '엑셀 표를 CSV로 저장한 파일이나 메모장(.txt) 파일을 올리면 날짜별 메모로 나눠 넣어요.\n'
                    '• 엑셀: 첫 줄에 "날짜, 종류, 내용" 머리글 (종류는 폐사·접종·방문·배달·할일, 비우면 내용으로 추정)\n'
                    '• 메모장: 줄 맨 앞에 2026-09-03 처럼 날짜를 쓰면 새 메모, 아래 줄은 그 메모에 이어 붙어요. [폐사] 처럼 종류를 붙일 수 있어요.\n'
                    '• 같은 날짜·같은 내용의 메모가 이미 있으면 건너뛰어요.',
                    style: TextStyle(fontSize: 12, color: AppColors.brandInk, height: 1.55),
                  ),
                ),
                const SizedBox(height: 18),
                const Text('양식장', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                OutlineButton(label: farm?.name ?? '양식장 고르기', onPressed: _busy ? null : () => _pickFarm(farms)),
                const SizedBox(height: 18),
                const Text('파일', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                OutlineButton(label: _file?.name ?? 'CSV / 메모장 파일 고르기', onPressed: _busy || _farmId == null ? null : _pickFile),
                if (_farmId == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('먼저 양식장을 골라 주세요.', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.dangerDark, height: 1.45)),
                  ),
                if (_busy && p == null) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
                if (p != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    '${p.format == 'csv' ? '엑셀 CSV' : '메모장'}에서 메모 ${p.memos.length}건을 읽었어요'
                    '${p.memos.length != p.freshCount ? ' · 이미 있는 ${p.memos.length - p.freshCount}건은 건너뜀' : ''}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  if (p.warnings.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.warningTint, borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('읽지 않은 줄 ${p.warnings.length}개',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.warningTintInk)),
                          for (final w in p.warnings)
                            Text('• $w', style: const TextStyle(fontSize: 11.5, color: AppColors.warningTintInk, height: 1.45)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  for (final m in p.memos)
                    Opacity(
                      opacity: m.duplicate ? 0.45 : 1,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text([m.date, if (m.kind != null) '#${m.kind}', if (m.duplicate) '이미 있음 — 건너뜀'].join(' · '),
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textTertiary)),
                            const SizedBox(height: 2),
                            Text(m.body, style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary, height: 1.45)),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
            child: PrimaryButton(
              label: p == null ? '메모 올리기' : '메모 ${p.freshCount}건 올리기',
              icon: Icons.upload_file,
              onPressed: _busy || p == null || p.freshCount == 0 ? null : _upload,
            ),
          ),
        ],
      ),
    );
  }
}
