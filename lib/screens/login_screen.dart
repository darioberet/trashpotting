import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../routes.dart';
import '../models/app_user_profile.dart';
import '../repositories/user_profile_repository.dart';
import '../services/auth_service.dart';
import '../state/app_session.dart';

class LoginScreen extends StatefulWidget {
  LoginScreen({
    super.key,
    AuthService? authService,
    UserProfileRepository? userProfileRepository,
  }) : _authService = authService ?? AuthService(),
       _userProfileRepository =
           userProfileRepository ?? UserProfileRepository();

  final AuthService _authService;
  final UserProfileRepository _userProfileRepository;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Inserisci email';
    final looksValid = email.contains('@') && email.contains('.');
    if (!looksValid) return 'Email non valida';
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Inserisci password';
    if (password.length < 6) return 'Minimo 6 caratteri';
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
      final credential = await widget._authService.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final user = credential.user;
      if (user != null) {
        await widget._userProfileRepository.ensureProfile(
          AppUserProfile.fromAuthUser(user),
        );
      }
      if (!mounted) return;
      session.publishInfo('Login effettuato.');
      context.go(AppRoutes.mappa);
    } catch (e) {
      if (!mounted) return;
      session.publishError(e, fallback: 'Login non riuscito.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final session = AppSessionScope.watch(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Icon(Icons.delete_sweep_outlined, size: 56, color: cs.primary),
                const SizedBox(height: 12),
                Text(
                  'Bentornato su Trashpotting',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Accedi per inviare segnalazioni e vedere i tuoi dati.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [
                          AutofillHints.username,
                          AutofillHints.email,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validatePassword,
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
                  icon: const Icon(Icons.login),
                  label: Text(_busy ? 'Accesso in corso...' : 'Accedi'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () {
                          context.push(AppRoutes.register);
                        },
                  child: const Text('Non hai un account? Registrati'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
