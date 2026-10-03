import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/data_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/farm.dart';
import '../../data/models/ocean_reading.dart';
import '../../data/services/address_geocoder.dart';
import '../../data/services/address_search_service.dart';
import '../../data/services/location_service.dart';

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
  late final TextEditingController _detailAddressController;
  late final TextEditingController _phoneController;
  OceanStation? _selectedStation;

  /// Nearest station to the searched 주소 — the primary suggestion. The manual
  /// dropdown below is the fallback / override.
  StationDistance? _recommended;
  bool _recommending = false;
  bool _pickedManually = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _addressController = TextEditingController(text: existing?.address ?? '');
    _detailAddressController = TextEditingController();
    _phoneController = TextEditingController(text: existing?.ownerContact ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _detailAddressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _searchAddress() async {
    final result = await AddressSearchService().search();
    if (result != null && mounted) {
      setState(() {
        _addressController.text = result.address;
        _detailAddressController.clear();
        _recommended = null;
      });
      _recommendStation(result.address);
    }
  }

  /// Geocodes [address] and recommends the nearest station. Pre-selects it
  /// unless the user already chose one by hand.
  Future<void> _recommendStation(String address) async {
    setState(() => _recommending = true);
    StationDistance? nearest;
    try {
      final point = await AddressGeocoder().locate(address);
      final stations = await ref.read(oceanStationsProvider.future);
      if (point != null) {
        final sorted = sortByDistance(point, stations);
        nearest = sorted.isEmpty ? null : sorted.first;
      }
    } catch (_) {
      // Recommendation is best-effort; the manual dropdown still works.
    }
    // A newer search may have replaced the address while this one was running.
    if (!mounted || _addressController.text != address) return;
    setState(() {
      _recommending = false;
      _recommended = nearest;
      if (nearest != null && !_pickedManually) _selectedStation = nearest.station;
    });
  }

  /// The optional 상세 주소 has no column of its own, so it is stored
  /// appended to the 도로명 주소 ("도로명 상세").
  String get _fullAddress {
    final base = _addressController.text.trim();
    final detail = _detailAddressController.text.trim();
    return detail.isEmpty ? base : '$base $detail';
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
          address: _fullAddress,
          ownerContact: _phoneController.text.trim(),
          region: region,
          nearestStationCode: stationCode,
          nearestStationName: stationName,
        );
      } else {
        await repo.updateFarm(
          widget.existing!.id,
          name: _nameController.text.trim(),
          address: _fullAddress,
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

  Widget _buildRecommendation() {
    final String text;
    final bool selected;
    VoidCallback? onTap;
    if (_addressController.text.trim().isEmpty) {
      return const _RecommendationBox(
        icon: Icons.place_outlined,
        text: '위치를 검색하면 가까운 수온 관측소를 추천해 드려요.',
      );
    }
    if (_recommending) {
      return const _RecommendationBox(icon: Icons.autorenew, text: '주소 기반으로 가까운 관측소를 찾는 중…');
    }
    final rec = _recommended;
    if (rec == null) {
      return const _RecommendationBox(
        icon: Icons.info_outline,
        text: '주소로 관측소를 찾지 못했어요. 아래에서 직접 선택해주세요. (비워두면 내 바다 위치로 설정)',
      );
    }
    selected = _selectedStation?.code == rec.station.code;
    text = '${rec.station.name} · 약 ${rec.distanceKm.toStringAsFixed(rec.distanceKm < 10 ? 1 : 0)}km';
    if (!selected) onTap = () => setState(() => _selectedStation = rec.station);
    return _RecommendationBox(
      icon: selected ? Icons.check_circle : Icons.recommend_outlined,
      title: '입력한 주소 기준 추천',
      text: selected ? text : '$text (탭하여 선택)',
      highlighted: true,
      onTap: onTap,
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
                const SizedBox(height: 8),
                TextFormField(
                  controller: _detailAddressController,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: _decoration('상세 주소 (선택) 예: 2동 양식장'),
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
                const _FieldLabel('인근 수온 관측소'),
                const SizedBox(height: 6),
                _buildRecommendation(),
                const SizedBox(height: 10),
                const _FieldLabel('다른 관측소 직접 선택 (선택)'),
                const SizedBox(height: 6),
                stationsAsync.when(
                  data: (stations) => DropdownButtonFormField<OceanStation>(
                    // Keyed by the current choice so a recommendation arriving
                    // later refreshes the displayed value.
                    key: ValueKey(_selectedStation?.code),
                    initialValue: _selectedStation,
                    decoration: _decoration('선택 안 함'),
                    style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
                    items: stations
                        .map((s) => DropdownMenuItem(value: s, child: Text(s.name, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (s) => setState(() {
                      _selectedStation = s;
                      _pickedManually = true;
                    }),
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

class _RecommendationBox extends StatelessWidget {
  const _RecommendationBox({required this.icon, required this.text, this.title, this.highlighted = false, this.onTap});

  final IconData icon;
  final String text;
  final String? title;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: highlighted ? AppColors.brandTint : AppColors.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: highlighted ? AppColors.brand : AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Text(title!, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.brand)),
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
                      color: highlighted ? AppColors.brandDark : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
