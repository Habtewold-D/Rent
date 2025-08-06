class Validators {
  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim());
    return ok ? null : 'Enter a valid email';
  }

  static String? password(String? v) {
    if (v == null || v.length < 6) return 'Min 6 characters';
    return null;
  }

  static String? nonEmpty(String? v, String label) {
    if (v == null || v.trim().isEmpty) return '$label is required';
    return null;
  }

  // Ethiopian phone numbers: +2519XXXXXXXX or 09XXXXXXXX
  static String? ethiopianPhone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Phone is required';
    final s = v.trim();
    final ok = RegExp(r'^(?:\+251|0)[79]\d{8}$').hasMatch(s);
    // Backend allows 07XXXXXXXX or 09XXXXXXXX (and +2517 / +2519)
    return ok ? null : 'Please provide a valid Ethiopian phone number';
  }
}
