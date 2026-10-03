/// Signup input rules, ported from aquaconnect_web's `lib/utils/validators.dart`.
///
/// `server/src/lib/validators.js` enforces the same rules — change both
/// together, or the form passes and the submit fails with a 400. Each
/// returns a user-facing message, or null when the value is fine
/// (`TextFormField.validator` convention).
library;

final RegExp _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final RegExp _nonDigit = RegExp(r'\D');

String normalizeEmail(String? value) => (value ?? '').trim().toLowerCase();

String digitsOnly(String? value) => (value ?? '').replaceAll(_nonDigit, '');

String? validateRequired(String? value, String label) {
  if (value == null || value.trim().isEmpty) return '$label을(를) 입력해 주세요.';
  return null;
}

String? validateEmailRequired(String? value) {
  if (value == null || value.trim().isEmpty) return '이메일을 입력해 주세요.';
  if (!_emailRe.hasMatch(value.trim())) return '이메일 형식이 올바르지 않습니다.';
  return null;
}

/// 8+ characters, at least two of letters / digits / symbols.
String? validatePassword(String? value) {
  final password = value ?? '';
  if (password.length < 8) return '비밀번호는 8자 이상이어야 합니다.';
  var kinds = 0;
  if (RegExp(r'[A-Za-z]').hasMatch(password)) kinds++;
  if (RegExp(r'\d').hasMatch(password)) kinds++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) kinds++;
  if (kinds < 2) return '비밀번호는 영문·숫자·특수문자 중 2종 이상을 조합해야 합니다.';
  return null;
}

String? validatePhone(String? value) {
  final digits = digitsOnly(value);
  if (digits.length < 10 || digits.length > 11) return '휴대폰 번호를 정확히 입력해 주세요.';
  return null;
}

/// 사업자등록번호 10 digits + the NTS check digit. Only rules out impossible
/// numbers — whether it's actually registered isn't verified.
String? validateBizRegNo(String? value) {
  final digits = digitsOnly(value);
  if (digits.length != 10) return '사업자등록번호는 숫자 10자리여야 합니다.';
  const weights = [1, 3, 7, 1, 3, 7, 1, 3, 5];
  final d = digits.split('').map(int.parse).toList();
  var total = 0;
  for (var i = 0; i < 9; i++) {
    total += d[i] * weights[i];
  }
  total += (d[8] * 5) ~/ 10;
  if ((10 - total % 10) % 10 != d[9]) return '올바르지 않은 사업자등록번호입니다.';
  return null;
}

/// Optional field: empty passes, anything typed must be a possible number.
String? validateOptionalBizRegNo(String? value) => digitsOnly(value).isEmpty ? null : validateBizRegNo(value);
