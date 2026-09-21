/// Shared field validators. Each returns an Arabic error message, or null when
/// the value is acceptable — the shape `TextFormField.validator` expects.

/// Egyptian mobile: 11 digits starting 010 / 011 / 012 / 015.
/// Accepts spaces/dashes and the +20 / 0020 country prefix.
String? validateEgyptPhone(String? raw) {
  final v = (raw ?? '').trim();
  if (v.isEmpty) return 'رقم الهاتف مطلوب';

  var digits = v.replaceAll(RegExp(r'[\s\-()]'), '');
  if (digits.startsWith('+20')) digits = '0${digits.substring(3)}';
  if (digits.startsWith('0020')) digits = '0${digits.substring(4)}';
  if (digits.startsWith('20') && digits.length == 12) digits = '0${digits.substring(2)}';

  if (!RegExp(r'^\d+$').hasMatch(digits)) return 'رقم الهاتف يجب أن يحتوي أرقاماً فقط';
  if (digits.length != 11) return 'رقم الهاتف يجب أن يكون 11 رقماً (مثال: 01012345678)';
  if (!RegExp(r'^01[0125]').hasMatch(digits)) {
    return 'رقم غير صحيح — يجب أن يبدأ بـ 010 أو 011 أو 012 أو 015';
  }
  return null;
}

/// Normalises a phone to the 11-digit local form for sending to the API.
String normaliseEgyptPhone(String raw) {
  var digits = raw.trim().replaceAll(RegExp(r'[\s\-()]'), '');
  if (digits.startsWith('+20')) digits = '0${digits.substring(3)}';
  if (digits.startsWith('0020')) digits = '0${digits.substring(4)}';
  if (digits.startsWith('20') && digits.length == 12) digits = '0${digits.substring(2)}';
  return digits;
}

String? validateEmail(String? raw) {
  final v = (raw ?? '').trim();
  if (v.isEmpty) return 'البريد الإلكتروني مطلوب';
  // Requires a dot-separated TLD — "name@gmail" must not pass.
  if (!RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$').hasMatch(v)) {
    return 'بريد إلكتروني غير صحيح (مثال: name@gmail.com)';
  }
  return null;
}

String? validateUsername(String? raw) {
  final v = (raw ?? '').trim();
  if (v.isEmpty) return 'اسم المستخدم مطلوب';
  if (v.length < 3) return 'اسم المستخدم 3 أحرف على الأقل';
  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v)) {
    return 'حروف إنجليزية وأرقام و _ فقط، بدون مسافات';
  }
  return null;
}

String? validateFullName(String? raw) {
  final v = (raw ?? '').trim();
  if (v.isEmpty) return 'الاسم بالكامل مطلوب';
  if (v.length < 3) return 'الاسم قصير جداً';
  if (!v.contains(' ')) return 'يرجى إدخال الاسم الثنائي على الأقل';
  return null;
}

String? validateAge(String? raw) {
  final v = (raw ?? '').trim();
  if (v.isEmpty) return 'العمر مطلوب';
  final n = int.tryParse(v);
  if (n == null) return 'يرجى إدخال رقم صحيح';
  if (n < 1 || n > 120) return 'العمر يجب أن يكون بين 1 و 120';
  return null;
}

String? validatePassword(String? raw) {
  final v = raw ?? '';
  if (v.isEmpty) return 'كلمة المرور مطلوبة';
  if (v.length < 6) return 'كلمة المرور 6 أحرف على الأقل';
  return null;
}

String? validateRequired(String? raw, String fieldLabel) {
  if ((raw ?? '').trim().isEmpty) return '$fieldLabel مطلوب';
  return null;
}
