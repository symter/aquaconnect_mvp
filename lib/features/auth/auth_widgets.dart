import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

// Form pieces shared by 회원가입 (signup_screen.dart) and 초대 수락
// (invite_accept_screen.dart).

/// Outlined text field with icon, helper and optional password toggle.
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
    this.hint,
    this.helper,
    this.keyboardType = TextInputType.text,
    this.action = TextInputAction.next,
    this.obscure = false,
    this.onToggleObscure,
    this.onChanged,
    this.suffix,
    this.last = false,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?)? validator;
  final String? hint;
  final String? helper;
  final TextInputType keyboardType;
  final TextInputAction action;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        textInputAction: action,
        onChanged: onChanged,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helper,
          helperMaxLines: 2,
          prefixIcon: Icon(icon),
          suffixIcon: suffix ??
              (onToggleObscure == null
                  ? null
                  : IconButton(
                      tooltip: obscure ? '비밀번호 보기' : '비밀번호 숨기기',
                      icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: onToggleObscure,
                    )),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
    );
  }
}

/// One 약관 checkbox row ("[필수] 이용약관" + detail).
class TermsTile extends StatelessWidget {
  const TermsTile({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    this.required = false,
    this.detail,
    this.emphasized = false,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String title;
  final bool required;
  final String? detail;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: AppColors.brand,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 9),
                    child: Text.rich(
                      TextSpan(children: [
                        if (required)
                          TextSpan(
                            text: '[필수] ',
                            style: TextStyle(fontSize: emphasized ? 15 : 13, fontWeight: FontWeight.w800, color: AppColors.brand),
                          ),
                        TextSpan(
                          text: title,
                          style: TextStyle(
                            fontSize: emphasized ? 15 : 13,
                            fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ]),
                    ),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 4),
                    Text(detail!, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Red inline error box under a form.
class AuthErrorBox extends StatelessWidget {
  const AuthErrorBox({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(color: AppColors.dangerTint, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 13, color: AppColors.dangerDark))),
        ],
      ),
    );
  }
}
