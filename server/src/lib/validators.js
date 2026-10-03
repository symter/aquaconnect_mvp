// Signup input rules, ported from aquaconnect_web's server/validators.py.
// lib/core/utils/validators.dart mirrors these on the client — change both
// together, or the form passes and the submit fails with a 400.
// Each returns a user-facing message, or null when the value is fine.

const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

export const normalizeEmail = (value) => String(value ?? '').trim().toLowerCase();
export const digitsOnly = (value) => String(value ?? '').replace(/\D/g, '');

export function validateEmail(value) {
  const email = String(value ?? '').trim();
  if (!email) return '이메일을 입력해 주세요.';
  if (!EMAIL_RE.test(email)) return '이메일 형식이 올바르지 않습니다.';
  return null;
}

// 8+ chars, at least two of letters / digits / symbols.
export function validatePassword(value) {
  const password = String(value ?? '');
  if (password.length < 8) return '비밀번호는 8자 이상이어야 합니다.';
  const kinds = [/[A-Za-z]/, /\d/, /[^A-Za-z0-9]/].filter((re) => re.test(password)).length;
  if (kinds < 2) return '비밀번호는 영문·숫자·특수문자 중 2종 이상을 조합해야 합니다.';
  return null;
}

export function validatePhone(value) {
  const digits = digitsOnly(value);
  if (digits.length < 10 || digits.length > 11) return '휴대폰 번호를 정확히 입력해 주세요.';
  return null;
}

// 사업자등록번호 10 digits + the NTS check digit. Only rules out impossible
// numbers — whether it's actually registered isn't verified.
export function validateBizRegNo(value) {
  const digits = digitsOnly(value);
  if (digits.length !== 10) return '사업자등록번호는 숫자 10자리여야 합니다.';
  const weights = [1, 3, 7, 1, 3, 7, 1, 3, 5];
  const d = [...digits].map(Number);
  let total = weights.reduce((sum, w, i) => sum + d[i] * w, 0);
  total += Math.floor((d[8] * 5) / 10);
  if ((10 - (total % 10)) % 10 !== d[9]) return '올바르지 않은 사업자등록번호입니다.';
  return null;
}

// 010-1234-5678 / 02-123-4567 style, for display and tel: links.
export function formatPhone(value) {
  const d = digitsOnly(value);
  if (d.length === 11) return `${d.slice(0, 3)}-${d.slice(3, 7)}-${d.slice(7)}`;
  if (d.length === 10) return d.startsWith('02') ? `${d.slice(0, 2)}-${d.slice(2, 6)}-${d.slice(6)}` : `${d.slice(0, 3)}-${d.slice(3, 6)}-${d.slice(6)}`;
  return d;
}
