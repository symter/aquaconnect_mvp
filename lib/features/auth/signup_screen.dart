import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/responsive_mobile_frame.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/services/address_search_service.dart';
import 'auth_widgets.dart';

/// 수산질병관리원 회원가입 — aquaconnect_web's signup wizard, minus the
/// 회원 유형 step (only institutes have accounts here; farms use share
/// links), the 사업자등록증 upload and the admin approval. Submitting
/// creates the institute + owner account and signs straight in.
///
/// 1. 기본정보 → 2. 관리원 정보 → 3. 약관 동의
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  static const _totalSteps = 3;
  static const _stepLabels = ['기본정보 입력', '관리원 정보 입력', '약관 동의'];

  final _formKeys = [GlobalKey<FormState>(), GlobalKey<FormState>()];

  // Every step's input lives here (not in the step widgets) so going back
  // and forth keeps it.
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  final _phone = TextEditingController();
  final _orgName = TextEditingController();
  final _address = TextEditingController();
  final _bizRegNo = TextEditingController();

  int _step = 1;
  bool _busy = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _termsAgreed = false;
  bool _privacyAgreed = false;
  bool _marketingAgreed = false;
  String? _error;

  /// Email that passed the duplicate check; editing the field invalidates it.
  String? _checkedEmail;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _passwordConfirm, _phone, _orgName, _address, _bizRegNo]) {
      c.dispose();
    }
    super.dispose();
  }

  void _back() {
    if (_busy) return;
    if (_step > 1) {
      setState(() {
        _step--;
        _error = null;
      });
    } else {
      context.pop();
    }
  }

  Future<void> _next() async {
    setState(() => _error = null);
    switch (_step) {
      case 1:
        if (!(_formKeys[0].currentState?.validate() ?? false)) return;
        // Ask now rather than bouncing back with a 409 after the last step.
        if (!await _ensureEmailAvailable()) return;
      case 2:
        if (!(_formKeys[1].currentState?.validate() ?? false)) return;
      default:
        if (!_termsAgreed || !_privacyAgreed) {
          setState(() => _error = '필수 약관에 동의해야 가입할 수 있습니다.');
          return;
        }
        return _submit();
    }
    setState(() => _step++);
  }

  Future<bool> _ensureEmailAvailable() async {
    final email = normalizeEmail(_email.text);
    if (_checkedEmail == email) return true;
    setState(() => _busy = true);
    try {
      final available = await ref.read(authRepositoryProvider).isEmailAvailable(email);
      if (!mounted) return false;
      if (!available) {
        setState(() => _error = '이미 가입된 이메일입니다. 로그인하거나 다른 이메일을 사용해 주세요.');
        return false;
      }
      _checkedEmail = email;
      return true;
    } catch (_) {
      // Don't block on a failed check — the server decides on submit anyway.
      return true;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _searchAddress() async {
    final result = await AddressSearchService().search();
    if (result != null && mounted) setState(() => _address.text = result.address);
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final auth = ref.read(authRepositoryProvider);
    try {
      var termsVersion = '';
      try {
        termsVersion = await auth.termsVersion();
      } catch (_) {}
      final bizRegNo = digitsOnly(_bizRegNo.text);
      await auth.signUp(SignupRequest(
        name: _name.text.trim(),
        email: normalizeEmail(_email.text),
        password: _password.text,
        phone: digitsOnly(_phone.text),
        organizationName: _orgName.text.trim(),
        address: _address.text.trim(),
        businessRegNo: bizRegNo.isEmpty ? null : bizRegNo,
        termsVersion: termsVersion,
        marketingAgreed: _marketingAgreed,
      ));
      // Signed in now — the router's redirect takes it from here to Home.
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ResponsiveMobileFrame(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: '뒤로',
                      onPressed: _busy ? null : _back,
                      icon: const Icon(Icons.arrow_back, color: AppColors.brandDark),
                    ),
                    const Text('회원가입',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.brandDark)),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _WizardProgress(step: _step, total: _totalSteps, label: _stepLabels[_step - 1]),
                      const SizedBox(height: 22),
                      switch (_step) {
                        1 => _basicInfoStep(),
                        2 => _organizationStep(),
                        _ => _termsStep(),
                      },
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        AuthErrorBox(message: _error!),
                      ],
                      const SizedBox(height: 22),
                      PrimaryButton(
                        label: _busy ? '처리 중...' : (_step == _totalSteps ? '가입하고 시작하기' : '다음'),
                        onPressed: _busy ? null : _next,
                      ),
                      if (_step == 1) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _busy ? null : () => context.pop(),
                          child: const Text('이미 계정이 있어요 · 로그인',
                              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 1단계: 기본정보 ───────────────────────────────────────────────

  Widget _basicInfoStep() {
    return Form(
      key: _formKeys[0],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthTextField(controller: _name, label: '대표자명', icon: Icons.badge_outlined, validator: (v) => validateRequired(v, '대표자명')),
          AuthTextField(
            controller: _email,
            label: '이메일',
            icon: Icons.email_outlined,
            hint: 'example@email.com',
            helper: '이 이메일이 로그인 계정이 됩니다.',
            keyboardType: TextInputType.emailAddress,
            validator: validateEmailRequired,
            onChanged: (_) => _checkedEmail = null,
          ),
          AuthTextField(
            controller: _password,
            label: '비밀번호',
            icon: Icons.lock_outline,
            obscure: _obscurePassword,
            helper: '8자 이상, 영문·숫자·특수문자 중 2종 이상',
            onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
            validator: validatePassword,
          ),
          AuthTextField(
            controller: _passwordConfirm,
            label: '비밀번호 확인',
            icon: Icons.lock_outline,
            obscure: _obscureConfirm,
            onToggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
            validator: (v) => v != _password.text ? '비밀번호가 일치하지 않습니다.' : null,
          ),
          AuthTextField(
            controller: _phone,
            label: '휴대폰 번호',
            icon: Icons.phone_outlined,
            hint: '010-0000-0000',
            helper: '어가가 공유 리포트에서 "전화 걸기"를 누르면 이 번호로 연결됩니다.',
            keyboardType: TextInputType.phone,
            action: TextInputAction.done,
            validator: validatePhone,
            last: true,
          ),
        ],
      ),
    );
  }

  // ── 2단계: 관리원 정보 ────────────────────────────────────────────

  Widget _organizationStep() {
    return Form(
      key: _formKeys[1],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthTextField(
            controller: _orgName,
            label: '수산질병관리원명',
            icon: Icons.local_hospital_outlined,
            validator: (v) => validateRequired(v, '수산질병관리원명'),
          ),
          AuthTextField(
            controller: _address,
            label: '관리원 주소',
            icon: Icons.location_on_outlined,
            helper: '오른쪽 돋보기로 주소를 검색하거나 직접 입력하세요.',
            validator: (v) => validateRequired(v, '관리원 주소'),
            suffix: IconButton(tooltip: '주소 검색', icon: const Icon(Icons.search), onPressed: _searchAddress),
          ),
          AuthTextField(
            controller: _bizRegNo,
            label: '사업자등록번호 (선택)',
            icon: Icons.numbers_outlined,
            hint: '000-00-00000',
            keyboardType: TextInputType.number,
            action: TextInputAction.done,
            validator: validateOptionalBizRegNo,
            last: true,
          ),
          const SizedBox(height: 12),
          const Text(
            '양식장·구성원·바다 위치는 가입 후 마이페이지에서 등록합니다.',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  // ── 3단계: 약관 동의 ──────────────────────────────────────────────

  Widget _termsStep() {
    final allAgreed = _termsAgreed && _privacyAgreed && _marketingAgreed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: TermsTile(
            value: allAgreed,
            emphasized: true,
            title: '전체 동의',
            onChanged: (v) => setState(() {
              _termsAgreed = v;
              _privacyAgreed = v;
              _marketingAgreed = v;
              _error = null;
            }),
          ),
        ),
        const SizedBox(height: 8),
        TermsTile(
          value: _termsAgreed,
          required: true,
          title: '이용약관',
          detail: 'AquaConnect 서비스 이용 조건과 회원의 권리·의무를 규정합니다.',
          onChanged: (v) => setState(() => _termsAgreed = v),
        ),
        TermsTile(
          value: _privacyAgreed,
          required: true,
          title: '개인정보 수집·이용 동의',
          detail: '대표자명·이메일·휴대폰 번호·관리원 정보를 계정 관리와 서비스 제공에 이용합니다.',
          onChanged: (v) => setState(() => _privacyAgreed = v),
        ),
        TermsTile(
          value: _marketingAgreed,
          title: '마케팅 정보 수신 (선택)',
          detail: '신규 기능과 이벤트 안내를 이메일로 받습니다.',
          onChanged: (v) => setState(() => _marketingAgreed = v),
        ),
        const SizedBox(height: 12),
        const Text(
          '가입하면 바로 로그인되어 AquaConnect를 사용할 수 있어요.',
          style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
        ),
      ],
    );
  }
}

/// "2 / 3 · 관리원 정보 입력" + a linear progress bar.
class _WizardProgress extends StatelessWidget {
  const _WizardProgress({required this.step, required this.total, required this.label});

  final int step;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('$step / $total', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.brand)),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: step / total,
            minHeight: 6,
            backgroundColor: AppColors.border,
            color: AppColors.brand,
          ),
        ),
      ],
    );
  }
}
