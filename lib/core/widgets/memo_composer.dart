import 'package:flutter/material.dart';

import '../../data/models/farm.dart';
import '../../data/models/memo.dart';
import '../theme/app_colors.dart';
import 'camera_capture_screen.dart';

/// What the composer hands to its owner on send.
class MemoDraft {
  const MemoDraft({required this.content, required this.tags, required this.photos, this.farm});

  final String content;
  final Farm? farm;
  final List<String> tags;
  final List<MemoPhotoUpload> photos;
}

/// Memo input pinned to the bottom of Home and Memo:
/// [+ 프리셋] [입력창] [카메라] [전송]. Typing `/` opens a farm-tag
/// autocomplete popover ("'/' 로 양식장 지정"). Selected farm, presets and
/// photos show above the input and can be removed before sending.
class MemoComposer extends StatefulWidget {
  const MemoComposer({
    super.key,
    required this.farms,
    required this.onSubmit,
    this.hintText = "지금 본 것 적어두기 ('/' 로 양식장 지정)",
  });

  final List<Farm> farms;

  /// Should throw on failure — the composer then keeps the draft and shows
  /// the error instead of clearing.
  final Future<void> Function(MemoDraft draft) onSubmit;
  final String hintText;

  @override
  State<MemoComposer> createState() => _MemoComposerState();
}

class _MemoComposerState extends State<MemoComposer> {
  static const presets = ['배달완료', '폐사', '투약', '방문'];
  static const maxPhotos = 5;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _plusKey = GlobalKey();
  Farm? _selectedFarm;
  final List<String> _selectedPresets = [];
  final List<MemoPhotoUpload> _photos = [];
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String? get _slashQuery {
    final text = _controller.text;
    final slashIndex = text.lastIndexOf('/');
    if (slashIndex == -1) return null;
    final after = text.substring(slashIndex + 1);
    if (after.contains(' ') || after.contains('\n')) return null;
    return after;
  }

  List<Farm> get _suggestions {
    final query = _slashQuery;
    if (query == null) return const [];
    if (query.isEmpty) return widget.farms;
    return widget.farms.where((f) => f.name.contains(query)).toList();
  }

  bool get _canSend =>
      !_sending && (_controller.text.trim().isNotEmpty || _selectedPresets.isNotEmpty || _photos.isNotEmpty);

  void _pickFarm(Farm farm) {
    final text = _controller.text;
    final slashIndex = text.lastIndexOf('/');
    setState(() {
      _selectedFarm = farm;
      if (slashIndex != -1) {
        _controller.text = text.substring(0, slashIndex);
        _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
      }
    });
  }

  Future<void> _openPresets() async {
    final box = _plusKey.currentContext!.findRenderObject()! as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    // Header row + one row per preset + padding — opened above the bar so
    // it doesn't cover the input.
    final menuHeight = 30.0 + presets.length * kMinInteractiveDimension + 16;
    final picked = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        topLeft.dx,
        topLeft.dy - menuHeight - 12,
        overlay.size.width - topLeft.dx,
        overlay.size.height - topLeft.dy,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        const PopupMenuItem<String>(
          enabled: false,
          height: 30,
          child: Text('빠른 입력', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
        ),
        for (final preset in presets)
          CheckedPopupMenuItem<String>(
            value: preset,
            checked: _selectedPresets.contains(preset),
            child: Text(preset, style: const TextStyle(fontSize: 13.5)),
          ),
      ],
    );
    if (picked == null) return;
    setState(() {
      _selectedPresets.contains(picked) ? _selectedPresets.remove(picked) : _selectedPresets.add(picked);
    });
  }

  Future<void> _takePhoto() async {
    if (_photos.length >= maxPhotos) {
      _snack('사진은 최대 $maxPhotos장까지 첨부할 수 있어요.');
      return;
    }
    final photo = await CameraCaptureScreen.open(context);
    if (photo != null && mounted) setState(() => _photos.add(photo));
  }

  Future<void> _submit() async {
    if (!_canSend) return;
    final text = _controller.text.trim();
    final content = text.isNotEmpty
        ? text
        : (_selectedPresets.isNotEmpty ? _selectedPresets.join(', ') : '사진 첨부');
    setState(() => _sending = true);
    try {
      await widget.onSubmit(MemoDraft(
        content: content,
        farm: _selectedFarm,
        tags: List.of(_selectedPresets),
        photos: List.of(_photos),
      ));
      if (!mounted) return;
      setState(() {
        _controller.clear();
        _selectedFarm = null;
        _selectedPresets.clear();
        _photos.clear();
      });
    } catch (e) {
      _snack('메모를 저장하지 못했어요: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _suggestions;
    final hasAttachments = _selectedFarm != null || _selectedPresets.isNotEmpty || _photos.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (suggestions.isNotEmpty) _FarmSuggestions(farms: suggestions, onPick: _pickFarm),
        if (hasAttachments)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (_selectedFarm != null)
                  _RemovableChip(
                    label: _selectedFarm!.name,
                    icon: Icons.home_work_outlined,
                    onRemove: () => setState(() => _selectedFarm = null),
                  ),
                for (final preset in _selectedPresets)
                  _RemovableChip(label: preset, onRemove: () => setState(() => _selectedPresets.remove(preset))),
                for (var i = 0; i < _photos.length; i++)
                  _PhotoThumb(photo: _photos[i], onRemove: () => setState(() => _photos.removeAt(i))),
              ],
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _RoundIconButton(
              key: _plusKey,
              icon: Icons.add,
              tooltip: '빠른 입력 (배달완료·폐사·투약·방문)',
              onTap: _openPresets,
              highlighted: _selectedPresets.isNotEmpty,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                minLines: 1,
                maxLines: 4,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.background,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _RoundIconButton(
              icon: Icons.photo_camera_outlined,
              tooltip: '사진 찍기',
              onTap: _sending ? null : _takePhoto,
              badge: _photos.isEmpty ? null : '${_photos.length}',
            ),
            const SizedBox(width: 8),
            _RoundIconButton(
              icon: Icons.arrow_forward,
              tooltip: '저장',
              onTap: _canSend ? _submit : null,
              filled: true,
              loading: _sending,
            ),
          ],
        ),
      ],
    );
  }
}

class _FarmSuggestions extends StatelessWidget {
  const _FarmSuggestions({required this.farms, required this.onPick});

  final List<Farm> farms;
  final ValueChanged<Farm> onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.borderStrong),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Color(0x0F142846), blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 7, 12, 4),
            child: Text("'/' 입력 시 표시 · 등록된 양식장",
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
          ),
          for (final f in farms)
            InkWell(
              onTap: () => onPick(f),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(f.name, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
              ),
            ),
        ],
      ),
    );
  }
}

class _RemovableChip extends StatelessWidget {
  const _RemovableChip({required this.label, required this.onRemove, this.icon});

  final String label;
  final IconData? icon;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
      decoration: BoxDecoration(color: AppColors.brandTint, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: AppColors.brand), const SizedBox(width: 4)],
          Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.brand)),
          InkWell(
            onTap: onRemove,
            customBorder: const CircleBorder(),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.close, size: 14, color: AppColors.brand),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.photo, required this.onRemove});

  final MemoPhotoUpload photo;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(photo.bytes, width: 52, height: 52, fit: BoxFit.cover),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: InkWell(
              onTap: onRemove,
              customBorder: const CircleBorder(),
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(color: AppColors.neutralIconStrong, shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 13, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.filled = false,
    this.highlighted = false,
    this.loading = false,
    this.badge,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool filled;
  final bool highlighted;
  final bool loading;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final Color bg = filled
        ? (enabled || loading ? AppColors.brand : AppColors.brand.withValues(alpha: 0.4))
        : (highlighted ? AppColors.brandTint : AppColors.background);
    final Color fg = filled ? Colors.white : (highlighted ? AppColors.brand : AppColors.neutralIcon);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: loading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(icon, size: 18, color: fg),
              ),
              if (badge != null)
                Positioned(
                  top: -3,
                  right: -3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(10)),
                    child: Text(badge!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
