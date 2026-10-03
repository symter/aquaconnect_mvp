import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/env.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/responsive_mobile_frame.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController(text: Env.useMock ? 'leedonggil@haegang.kr' : '');
  final _passwordController = TextEditingController(text: Env.useMock ? 'demo1234' : '');
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signIn(
            email: _emailController.text,
            password: _passwordController.text,
          );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ResponsiveMobileFrame(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),
                  const Text(
                    'AquaConnect',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.brandDark),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '수산질병관리원 전용',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: '이메일', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: '비밀번호', border: OutlineInputBorder()),
                    onSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
                  ],
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: _loading ? '로그인 중...' : '로그인',
                    onPressed: _loading ? null : _submit,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('처음 사용하시나요?', style: TextStyle(fontSize: 12.5, color: AppColors.textTertiary)),
                      TextButton(
                        onPressed: _loading ? null : () => context.push('/signup'),
                        child: const Text('회원가입',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.brand)),
                      ),
                    ],
                  ),
                  if (Env.useMock) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Mock 모드 — 아무 이메일/비밀번호나 입력하면 이동길(해강수산질병관리원) 계정으로 로그인됩니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
