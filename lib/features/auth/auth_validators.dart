/// Validate form - port từ `modules/auth/schemas/auth.schema.ts` (Zod).
/// Trả về key dịch của lỗi, hoặc null nếu hợp lệ.
class AuthValidators {
  AuthValidators._();

  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? email(String v) {
    final s = v.trim();
    if (s.isEmpty) return 'auth.validation.required';
    if (s.length > 320 || !_email.hasMatch(s)) return 'auth.validation.email';
    return null;
  }

  static String? loginPassword(String v) {
    if (v.isEmpty) return 'auth.validation.required';
    if (v.length > 128) return 'auth.validation.passwordMax';
    return null;
  }

  static String? displayName(String v) {
    if (v.trim().isEmpty) return 'auth.validation.required';
    if (v.length > 150) return 'auth.validation.nameMax';
    return null;
  }

  static String? phone(String v) =>
      v.isEmpty || (v.length >= 7 && v.length <= 32) ? null : 'auth.validation.phone';

  static String? newPassword(String v) {
    if (v.length < 6) return 'auth.validation.passwordMin';
    if (v.length > 128) return 'auth.validation.passwordMax';
    return null;
  }

  static String? confirm(String password, String confirm) =>
      password == confirm ? null : 'auth.validation.confirmPassword';
}
