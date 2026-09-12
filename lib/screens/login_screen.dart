import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/form_validators.dart';
import '../models/app_user_profile.dart';
import '../repositories/user_profile_repository.dart';
import '../routes.dart';
import '../services/auth_service.dart';
import '../state/app_session.dart';
import '../theme/app_colors.dart';

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
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _busy = false;
  bool _obscurePassword = true;

  Future<void> _showPasswordReset(BuildContext context) async {
    final controller = TextEditingController(text: _emailController.text.trim());
    final session = AppSessionScope.of(context);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recupero password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Inserisci la tua email. Riceverai un link per reimpostare la password.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'nome@esempio.it'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(88, 40)),
            onPressed: () async {
              final email = controller.text.trim();
              if (email.isEmpty) return;
              Navigator.of(ctx).pop();
              try {
                await widget._authService.sendPasswordResetEmail(email);
                if (!context.mounted) return;
                session.publishInfo('Email di recupero inviata a $email.');
              } catch (e) {
                if (!context.mounted) return;
                session.publishError(e, fallback: 'Invio email di recupero non riuscito.');
              }
            },
            child: const Text('Invia'),
          ),
        ],
      ),
    );
    controller.dispose();
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
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final session = AppSessionScope.watch(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                const SizedBox(height: 48),

                // Logo
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete_sweep_outlined, size: 22, color: AppColors.greenBrand),
                    const SizedBox(width: 6),
                    Text(
                      'Trashpotting',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppColors.greenBrand,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Accedi al tuo account',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 32),

                Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel('Email'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        focusNode: _emailFocus,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) =>
                            _passwordFocus.requestFocus(),
                        autofillHints: const [
                          AutofillHints.username,
                          AutofillHints.email,
                        ],
                        decoration: const InputDecoration(
                          hintText: 'nome@esempio.it',
                        ),
                        validator: FormValidators.email,
                      ),
                      const SizedBox(height: 16),
                      _FieldLabel('Password'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passwordController,
                        focusNode: _passwordFocus,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 18,
                              color: AppColors.textDisabled,
                            ),
                            onPressed: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: FormValidators.password,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _busy ? null : () => _showPasswordReset(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            minimumSize: const Size(48, 48),
                          ),
                          child: const Text('Password dimenticata?', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ),

                if (!session.firebaseReady) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Firebase non disponibile. Controlla la configurazione.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.error),
                    textAlign: TextAlign.center,
                  ),
                ],

                const SizedBox(height: 20),

                FilledButton(
                  onPressed: _busy || !session.firebaseReady ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Accedi'),
                ),

                const SizedBox(height: 32),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Non hai un account? ',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    TextButton(
                      onPressed: _busy ? null : () => context.push(AppRoutes.register),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        minimumSize: const Size(48, 48),
                      ),
                      child: const Text('Registrati', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
    );
  }
}
