abstract final class FormValidators {
  // Validates RFC-5321 subset: local@domain.tld with no consecutive dots.
  static final _emailRe = RegExp(
    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
  );

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Inserisci email';
    if (!_emailRe.hasMatch(v)) return 'Email non valida';
    return null;
  }

  static String? password(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Inserisci password';
    if (password.length < 6) return 'Minimo 6 caratteri';
    return null;
  }
}
