import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/form_validators.dart';
import '../repositories/user_profile_repository.dart';
import '../routes.dart';
import '../services/auth_service.dart';
import '../state/app_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';

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
    final controller = TextEditingController(
      text: _emailController.text.trim(),
    );
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
                session.publishError(
                  e,
                  fallback: 'Invio email di recupero non riuscito.',
                );
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
        await widget._userProfileRepository.ensureProfile(user.uid);
      }
      // Il router decide sul flag in sessione, non su un valore letto qui:
      // va riletto prima di navigare, altrimenti il valore ottimistico
      // (true) rimanda alla mappa un utente che deve fare l'onboarding.
      // In caso di errore di rete resta il valore ottimistico.
      session.refreshCurrentUser();
      await session.refreshOnboardingStatus();
      if (!mounted) return;
      session.publishInfo('Login effettuato.');
      context.go(
        session.onboardingComplete ? AppRoutes.mappa : AppRoutes.onboarding,
      );
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
    final session = AppSessionScope.watch(context);
    final topInset = MediaQuery.of(context).padding.top;
    const headerHeight = 360.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.forest,
        body: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height,
            ),
            child: Stack(
              children: [
                SizedBox(
                  height: headerHeight + topInset,
                  child: _AuthHero(topInset: topInset),
                ),
                Container(
                  margin: EdgeInsets.only(top: headerHeight + topInset - 44),
                  constraints: BoxConstraints(
                    minHeight:
                        MediaQuery.of(context).size.height -
                        headerHeight -
                        topInset +
                        44,
                  ),
                  padding: EdgeInsets.fromLTRB(
                    20,
                    28,
                    20,
                    24 + MediaQuery.of(context).padding.bottom,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.bgAlt,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: AutofillGroup(
                        child: Form(
                          key: _formKey,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Semantics(
                                header: true,
                                child: Text(
                                  'Bentornato',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Accedi per continuare a fare la differenza',
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 21 / 15,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 20),
                              AppTextField(
                                label: 'Email',
                                icon: AppIcons.email,
                                controller: _emailController,
                                focusNode: _emailFocus,
                                hintText: 'nome@esempio.it',
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) =>
                                    _passwordFocus.requestFocus(),
                                autofillHints: const [
                                  AutofillHints.username,
                                  AutofillHints.email,
                                ],
                                validator: FormValidators.email,
                              ),
                              const SizedBox(height: 14),
                              AppTextField(
                                label: 'Password',
                                icon: AppIcons.lock,
                                controller: _passwordController,
                                focusNode: _passwordFocus,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                autofillHints: const [AutofillHints.password],
                                validator: FormValidators.password,
                                suffix: IconButton(
                                  tooltip: _obscurePassword
                                      ? 'Mostra password'
                                      : 'Nascondi password',
                                  icon: Icon(
                                    _obscurePassword
                                        ? AppIcons.hidden
                                        : AppIcons.visible,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _showPasswordReset(context),
                                  child: const Text('Password dimenticata?'),
                                ),
                              ),
                              if (!session.firebaseReady) ...[
                                const SizedBox(height: 4),
                                const Text(
                                  'Firebase non disponibile. Controlla la '
                                  'configurazione.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.redText,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              AppButton(
                                label: 'Accedi',
                                icon: AppIcons.signIn,
                                loading: _busy,
                                onPressed: session.firebaseReady
                                    ? _submit
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              // Wrap: con testo ingrandito va a capo invece
                              // di sforare.
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  const Text(
                                    'Non hai un account?',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _busy
                                        ? null
                                        : () =>
                                              context.push(AppRoutes.register),
                                    style: TextButton.styleFrom(
                                      textStyle: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    child: const Text('Registrati'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Testata verde foresta del Login: foglie decorative, logo e i tre
/// "Segnala · Pulisci · Fai punti".
class _AuthHero extends StatelessWidget {
  const _AuthHero({required this.topInset});

  final double topInset;

  @override
  Widget build(BuildContext context) {
    Widget leaf(
      double left,
      double top,
      double size,
      double turns,
      Color color,
      double opacity,
    ) => Positioned(
      left: left,
      top: top,
      child: Transform.rotate(
        angle: turns * 2 * math.pi,
        child: Icon(
          AppIcons.leaf,
          size: size,
          color: color.withAlpha((opacity * 255).round()),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            leaf(-30, topInset + 40, 120, 0.06, AppColors.mint, 0.18),
            leaf(w - 90, topInset + 10, 110, -0.08, AppColors.mint, 0.14),
            leaf(w - 70, topInset + 210, 60, 0.17, AppColors.yellow, 0.5),
            leaf(24, topInset + 236, 34, -0.11, AppColors.yellow, 0.6),
            leaf(w * 0.64, topInset + 70, 26, 0.04, Colors.white, 0.25),
            Positioned(
              left: 0,
              right: 0,
              top: topInset + 64,
              child: Column(
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: AppColors.greenBrand,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        const BoxShadow(
                          color: AppColors.greenDark,
                          offset: Offset(0, 6),
                        ),
                        BoxShadow(
                          color: Colors.white.withAlpha(20),
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                    child: const Icon(
                      AppIcons.leaf,
                      size: 44,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Semantics(
                    header: true,
                    child: const Text(
                      'Trashpotting',
                      style: TextStyle(
                        fontSize: 34,
                        height: 40 / 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      _HeroChip(icon: AppIcons.place, label: 'Segnala'),
                      _HeroChip(icon: AppIcons.clean, label: 'Pulisci'),
                      _HeroChip(
                        icon: AppIcons.starFilled,
                        label: 'Fai punti',
                        highlighted: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({
    required this.icon,
    required this.label,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final fg = highlighted ? AppColors.onYellow : AppColors.mintText;
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.yellow : Colors.white.withAlpha(26),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: highlighted ? FontWeight.w800 : FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
