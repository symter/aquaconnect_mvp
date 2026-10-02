import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/buttons.dart';
import '../../data/models/member.dart';
import '../../data/services/address_search_service.dart';

/// 마이페이지 > 관리원 정보 (tap the profile card). 소유자·원장 can edit the
/// name / address / 대표 연락처 — each change lands in 변경 이력 — everyone
/// else sees it read-only.
class OrganizationInfoScreen extends ConsumerStatefulWidget {
  const OrganizationInfoScreen({super.key});

  @override
  ConsumerState<OrganizationInfoScreen> createState() => _OrganizationInfoScreenState();
}

class _OrganizationInfoScreenState extends ConsumerState<OrganizationInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  String _businessRegNo = '';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _canEdit {
    final role = ref.read(authRepositoryProvider).currentSession?.member.role;
    return role == MemberRole.owner || role == MemberRole.director;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final org = await ref.read(orgRepositoryProvider).getOrganization();
      if (!mounted) return;
      setState(() {
        _name.text = org.name;
        _address.text = org.address;
        _phone.text = org.phone;
        _businessRegNo = org.businessRegNo;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _searchAddress() async {
    final result = await AddressSearchService().search();
    if (result != null && mounted) setState(() => _address.text = result.address);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(orgRepositoryProvider).updateOrganization(
            name: _name.text.trim(),
            address: _address.text.trim(),
            phone: _phone.text.trim(),
          );
      // The institute name shows on Home / MyPage via the session.
      await ref.read(authRepositoryProvider).refreshSession();
      messenger.showSnackBar(const SnackBar(content: Text('관리원 정보를 저장했어요.')));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('저장하지 못했어요: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editable = _canEdit;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.brandDark,
        title: const Text('관리원 정보', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.brandDark)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('관리원 정보를 불러오지 못했어요.\n$_error', textAlign: TextAlign.center))
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    children: [
                      if (!editable)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppColors.brandTint, borderRadius: BorderRadius.circular(10)),
                          child: const Text('관리원 정보는 소유자·원장만 수정할 수 있어요.',
                              style: TextStyle(fontSize: 12, color: AppColors.brandInk)),
                        ),
                      _field(_name, '관리원명', Icons.local_hospital_outlined, editable,
                          validator: (v) => validateRequired(v, '관리원명')),
                      _field(
                        _address,
                        '주소',
                        Icons.location_on_outlined,
                        editable,
                        validator: (v) => validateRequired(v, '주소'),
                        suffix: editable ? IconButton(tooltip: '주소 검색', icon: const Icon(Icons.search), onPressed: _searchAddress) : null,
                      ),
                      _field(
                        _phone,
                        '대표 연락처 (선택)',
                        Icons.phone_outlined,
                        editable,
                        keyboardType: TextInputType.phone,
                        validator: (v) => (v ?? '').trim().isEmpty ? null : validatePhone(v),
                      ),
                      if (_businessRegNo.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('사업자등록번호 ${_formatBizRegNo(_businessRegNo)}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                      ],
                      if (editable) ...[
                        const SizedBox(height: 20),
                        PrimaryButton(label: _saving ? '저장 중...' : '저장', onPressed: _saving ? null : _save),
                        const SizedBox(height: 8),
                        const Text('수정한 내용은 마이페이지 > 변경 이력에 기록됩니다.',
                            textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon,
    bool editable, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        readOnly: !editable,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: suffix,
          filled: true,
          fillColor: editable ? AppColors.surface : AppColors.background,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
    );
  }

  static String _formatBizRegNo(String digits) =>
      digits.length == 10 ? '${digits.substring(0, 3)}-${digits.substring(3, 5)}-${digits.substring(5)}' : digits;
}
