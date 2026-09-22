import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/data_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/farm.dart';
import '../../data/models/ocean_reading.dart';
import '../../data/services/address_search_service.dart';

/// Create/edit form for a farm, opened as a bottom sheet from
/// [FarmManagementScreen]. 양식장명 / 위치 / 전화번호 are enforced as
/// required here (the DB schema itself only requires 위치). "위치" is set
/// only through the Daum 주소찾기 popup (see [AddressSearchService]), not
/// free-typed, per the 도로명 주소 검색 requirement.
class FarmFormSheet extends ConsumerStatefulWidget {
  const FarmFormSheet({super.key, this.existing});

  final Farm? existing;

  @override
  ConsumerState<FarmFormSheet> createState() => _FarmFormSheetState();
}

class _FarmFormSheetState extends ConsumerState<FarmFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  OceanStation? _selectedStation;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _addressController = TextEditingController(text: existing?.address ?? '');
    _phoneController = TextEditingController(text: existing?.ownerContact ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _searchAddress() async {
    final result = await AddressSearchService().search();
    if (result != null && mounted) {
      setState(() => _addressController.text = result.address);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);

    final String stationCode;
    final String stationName;
    if (_selectedStation != null) {
      stationCode = _selectedStation!.code;
      stationName = _selectedStation!.name;
    } else if (widget.existing != null) {
      stationCode = widget.existing!.nearestStationCode;
      stationName = widget.existing!.nearestStationName;
    } else {
      final mySea = ref.read(selectedOceanStationProvider).valueOrNull;
      stationCode = mySea?.code ?? '';
      stationName = mySea?.name ?? '';
    }
    final region = stationName.isNotEmpty ? stationName : (widget.existing?.region ?? '');

    try {
      final repo = ref.read(farmRepositoryProvider);
      if (widget.existing == null) {
        await repo.createFarm(
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          ownerContact: _phoneController.text.trim(),
          region: region,
          nearestStationCode: stationCode,
          nearestStationName: stationName,
        );
      } else {
        await repo.updateFarm(
          widget.existing!.id,
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          ownerContact: _phoneController.text.trim(),
          region: region,
          nearestStationCode: stationCode,
          nearestStationName: stationName,
        );
      }
      ref.invalidate(farmsProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장에 실패했습니다: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
      filled: true,
      fillColor: AppColors.background,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final stationsAsync = ref.watch(oceanStationsProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                Text(isEdit ? '양식장 정보 수정' : '양식장 등록',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.brandDark)),
                const SizedBox(height: 16),
                const _FieldLabel('양식장명 *'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  decoration: _decoration('예: 신일수산 1양식장'),
                  style: const TextStyle(fontSize: 13.5),
                  validator: (v) => (v == null || v.trim().isEmpty) ? '양식장명을 입력해주세요.' : null,
                ),
                const SizedBox(height: 14),
                const _FieldLabel('위치 *'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _addressController,
                  readOnly: true,
                  onTap: _searchAddress,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: _decoration('주소찾기로 도로명 주소를 검색하세요').copyWith(
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search, size: 18, color: AppColors.brand),
                      onPressed: _searchAddress,
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? '주소찾기로 위치를 지정해주세요.' : null,
                ),
                const SizedBox(height: 14),
                const _FieldLabel('전화번호 *'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: _decoration('예: 01012345678'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? '전화번호를 입력해주세요.' : null,
                ),
                const SizedBox(height: 14),
                const _FieldLabel('인근 수온 관측소 (선택 — 비워두면 내 바다 위치로 설정)'),
                const SizedBox(height: 6),
                stationsAsync.when(
                  data: (stations) => DropdownButtonFormField<OceanStation>(
                    initialValue: _selectedStation,
                    decoration: _decoration('선택 안 함'),
                    style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
                    items: stations
                        .map((s) => DropdownMenuItem(value: s, child: Text(s.name, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (s) => setState(() => _selectedStation = s),
                  ),
                  loading: () => const LinearProgressIndicator(minHeight: 2),
                  error: (e, _) => const Text('관측소 목록을 불러오지 못했습니다.', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(isEdit ? '수정 완료' : '등록하기', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary));
  }
}
