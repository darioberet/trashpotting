import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../routes.dart';
import '../core/form_validators.dart';
import '../core/legal.dart';
import '../repositories/user_profile_repository.dart';
import '../services/auth_service.dart';
import '../state/app_session.dart';

class RegisterScreen extends StatefulWidget {
  RegisterScreen({
    super.key,
    AuthService? authService,
    UserProfileRepository? userProfileRepository,
  }) : _authService = authService ?? AuthService(),
       _userProfileRepository =
           userProfileRepository ?? UserProfileRepository();

  final AuthService _authService;
  final UserProfileRepository _userProfileRepository;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _busy = false;
  bool _termsAccepted = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  String? _validateConfirm(String? value) {
    if ((value ?? '').isEmpty) return 'Conferma password';
    if (value != _passwordController.text) return 'Le password non coincidono';
    return null;
  }

  Future<void> _submit() async {
    if (_busy) return;

    final session = AppSessionScope.of(context);
    if (!session.firebaseReady) {
      session.publishInfo(
        'Backend non disponibile: verifica Firebase e riprova.',
      );
      return;
    }

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    setState(() => _busy = true);
    try {
      final credential = await widget._authService.registerWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final user = credential.user;
      if (user != null) {
        final username = _usernameController.text.trim();
        // Lo username vive solo su Firestore (users/{uid}.username): è da
        // lì che Profilo, classifica ed eventi leggono il nome.
        await widget._userProfileRepository.ensureProfile(
          user.uid,
          username: username.isEmpty ? null : username,
          acceptedTermsVersion: _termsAccepted ? LegalLinks.version : null,
        );
        if (username.isNotEmpty) session.setUsername(username);
        // Solo qui il flag viene esplicitamente impostato a false: è
        // l'unico punto in cui nasce un account nuovo — login non lo tocca
        // mai, quindi un utente già onboardato non rientra nel flusso.
        await widget._userProfileRepository.setOnboardingComplete(
          user.uid,
          false,
        );
      }
      if (credential.user != null) {
        await widget._authService.sendEmailVerification();
      }
      if (!mounted) return;
      session.publishInfo('Registrazione completata. Controlla la tua email.');
      context.go(AppRoutes.emailVerification);
    } catch (e) {
      if (!mounted) return;
      session.publishError(e, fallback: 'Registrazione non riuscita.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final session = AppSessionScope.watch(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Registrazione')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Crea il tuo account',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Dopo la registrazione dovrai verificare la tua email.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _usernameController,
                        focusNode: _nameFocus,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                        decoration: const InputDecoration(
                          labelText: 'Username (opzionale)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        focusNode: _emailFocus,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: FormValidators.email,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        focusNode: _passwordFocus,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => _confirmFocus.requestFocus(),
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 18,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        validator: FormValidators.password,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmController,
                        focusNode: _confirmFocus,
                        obscureText: _obscureConfirm,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Conferma password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 18,
                            ),
                            onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm,
                            ),
                          ),
                        ),
                        validator: _validateConfirm,
                      ),
                      const SizedBox(height: 8),
                      // Obbligatorio (GDPR e Google Play): senza accettazione
                      // il form non è valido e la registrazione non parte.
                      FormField<bool>(
                        initialValue: false,
                        validator: (v) => v == true
                            ? null
                            : 'Per registrarti devi accettare termini e privacy',
                        builder: (field) => _TermsCheckbox(
                          value: field.value ?? false,
                          errorText: field.errorText,
                          onChanged: (v) {
                            field.didChange(v);
                            _termsAccepted = v;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                if (!session.firebaseReady) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Firebase non disponibile. Controlla la configurazione.',
                    style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _busy || !session.firebaseReady ? null : _submit,
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: Text(
                    _busy ? 'Registrazione in corso...' : 'Registrati',
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _busy ? null : () => context.pop(),
                  child: const Text('Hai già un account? Torna al login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Ho letto e accetto i Termini d'uso e l'Informativa privacy", con i due
/// link apribili.
class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontSize: 13);
    final linkStyle = style?.copyWith(
      color: cs.primary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );

    WidgetSpan link(String label, Uri uri) => WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: InkWell(
        onTap: () => LegalLinks.open(uri),
        child: Text(label, style: linkStyle),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              isError: errorText != null,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text.rich(
                  TextSpan(
                    style: style,
                    children: [
                      const TextSpan(
                        text: 'Ho almeno 14 anni, ho letto e accetto i ',
                      ),
                      link('Termini d\'uso', LegalLinks.terms),
                      const TextSpan(text: ' e l\''),
                      link('Informativa privacy', LegalLinks.privacy),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              errorText!,
              style: TextStyle(color: cs.error, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
