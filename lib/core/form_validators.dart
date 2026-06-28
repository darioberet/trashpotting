abstract final class FormValidators {
  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Inserisci email';
    if (!email.contains('@') || !email.contains('.')) return 'Email non valida';
    return null;
  }

  static String? password(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Inserisci password';
    if (password.length < 6) return 'Minimo 6 caratteri';
    return null;
  }
}
