import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/notification_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/responsive_mobile_frame.dart';
import '../../data/models/invitation.dart';
import '../../data/models/member.dart';
import '../auth/auth_widgets.dart';

/// `/invite/:code` — the page an invited person opens. Shows which
/// institute invited them and as what, then a short signup form; joining
/// creates their account in that institute with the invited role and signs
/// them in. The link works once.
class InviteAcceptScreen extends ConsumerStatefulWidget {
  const InviteAcceptScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<InviteAcceptScreen> createState() => _InviteAcceptScreenState();
}

class _InviteAcceptScreenState extends ConsumerState<InviteAcceptScreen> {
  late Future<InvitationInfo> _info = ref.read(authRepositoryProvider).lookupInvitation(widget.code);

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  final _phone = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _termsAgreed = false;
  bool _privacyAgreed = false;
  bool _marketingAgreed = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _passwordConfirm, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _join(InvitationInfo info) async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_termsAgreed || !_privacyAgreed) {
      setState(() => _error = '필수 약관에 동의해야 가입할 수 있습니다.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).acceptInvitation(
            widget.code,
            InviteAcceptRequest(
              name: _name.text.trim(),
              email: normalizeEmail(_email.text),
              password: _password.text,
              phone: digitsOnly(_phone.text),
              termsVersion: info.termsVersion,
              marketingAgreed: _marketingAgreed,
            ),
          );
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOutAndStay() async {
    await ref.read(pushControllerProvider).detachBeforeSignOut();
    await ref.read(authRepositoryProvider).signOut();
    if (mounted) setState(() => _info = ref.read(authRepositoryProvider).lookupInvitation(widget.code));
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authStateProvider).valueOrNull;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ResponsiveMobileFrame(
        child: SafeArea(
          child: FutureBuilder<InvitationInfo>(
            future: _info,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) return _Unavailable(message: '${snapshot.error}'.replaceFirst('Exception: ', ''));
              final info = snapshot.data!;
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(info: info),
                    const SizedBox(height: 24),
                    if (session != null)
                      _SignedInNotice(name: session.member.name, onSignOut: _signOutAndStay)
                    else
                      _form(info),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _form(InvitationInfo info) {
    final allAgreed = _termsAgreed && _privacyAgreed && _marketingAgreed;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthTextField(controller: _name, label: '이름', icon: Icons.badge_outlined, validator: (v) => validateRequired(v, '이름')),
          AuthTextField(
            controller: _email,
            label: '이메일',
            icon: Icons.email_outlined,
            hint: 'example@email.com',
            helper: '이 이메일이 로그인 계정이 됩니다.',
            keyboardType: TextInputType.emailAddress,
            validator: validateEmailRequired,
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
            keyboardType: TextInputType.phone,
            action: TextInputAction.done,
            validator: validatePhone,
            last: true,
          ),
          const SizedBox(height: 16),
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
              }),
            ),
          ),
          TermsTile(
            value: _termsAgreed,
            required: true,
            title: '이용약관',
            onChanged: (v) => setState(() => _termsAgreed = v),
          ),
          TermsTile(
            value: _privacyAgreed,
            required: true,
            title: '개인정보 수집·이용 동의',
            detail: '이름·이메일·휴대폰 번호를 계정 관리와 서비스 제공에 이용합니다.',
            onChanged: (v) => setState(() => _privacyAgreed = v),
          ),
          TermsTile(
            value: _marketingAgreed,
            title: '마케팅 정보 수신 (선택)',
            onChanged: (v) => setState(() => _marketingAgreed = v),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            AuthErrorBox(message: _error!),
          ],
          const SizedBox(height: 18),
          PrimaryButton(label: _busy ? '가입 중...' : '가입하고 합류하기', onPressed: _busy ? null : () => _join(info)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : () => context.go('/login'),
            child: const Text('이미 계정이 있어요 · 로그인', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.info});

  final InvitationInfo info;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(color: AppColors.brandTint, shape: BoxShape.circle),
          child: const Icon(Icons.group_add_outlined, size: 30, color: AppColors.brand),
        ),
        const SizedBox(height: 16),
        Text(
          '${info.orgName}에서 초대했어요',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          [
            if (info.inviterName.isNotEmpty) '${info.inviterName}님이 보낸 초대',
            '${info.role.label}(으)로 합류합니다',
          ].join(' · '),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          '${info.expiresAt.month}월 ${info.expiresAt.day}일까지 사용할 수 있는 1회용 링크예요',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _SignedInNotice extends StatelessWidget {
  const _SignedInNotice({required this.name, required this.onSignOut});

  final String name;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.warningTint, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '지금 $name 계정으로 로그인되어 있어요. 이 초대로 새 계정을 만들려면 로그아웃한 뒤 계속하세요.',
            style: const TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.warningTintInk),
          ),
          const SizedBox(height: 12),
          OutlineButton(label: '로그아웃하고 계속', onPressed: onSignOut),
          TextButton(onPressed: () => context.go('/'), child: const Text('홈으로')),
        ],
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link_off, size: 40, color: AppColors.textFaint),
            const SizedBox(height: 14),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            const SizedBox(height: 18),
            OutlineButton(label: '로그인 화면으로', onPressed: () => context.go('/login')),
          ],
        ),
      ),
    );
  }
}
