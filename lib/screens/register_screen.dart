import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../routes.dart';
import '../core/form_validators.dart';
import '../core/legal.dart';
import '../repositories/leaderboard_repository.dart'
    show pointsPerCleanup, pointsPerReport;
import '../repositories/user_profile_repository.dart';
import '../services/auth_service.dart';
import '../state/app_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';
import '../widgets/tab_header.dart';

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

  @override
  void initState() {
    super.initState();
    // Solo in debug: account di prova già compilato, per registrare in fretta
    // gli utenti di test (la parte dopo il + cambia a ogni apertura).
    if (kDebugMode) {
      final n = Random().nextInt(10000) + 1;
      _emailController.text = 'polivastro123+$n@gmail.com';
      _passwordController.text = 'test1234';
      _confirmController.text = 'test1234';
      _termsAccepted = true;
    }
  }

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
    final session = AppSessionScope.watch(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: SizedBox(
                        height: 56,
                        child: Row(
                          children: [
                            HeaderCircleButton(
                              icon: AppIcons.back,
                              tooltip: 'Torna al login',
                              onPressed: () {
                                if (_busy) return;
                                context.canPop()
                                    ? context.pop()
                                    : context.go(AppRoutes.login);
                              },
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Registrazione',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _PointsBanner(),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                'Crea il tuo account',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Dopo la registrazione dovrai verificare la '
                              'tua email.',
                              style: TextStyle(
                                fontSize: 14,
                                height: 20 / 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 14),
                            AppTextField(
                              label: 'Username (opzionale)',
                              icon: AppIcons.username,
                              controller: _usernameController,
                              focusNode: _nameFocus,
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) =>
                                  _emailFocus.requestFocus(),
                              autofillHints: const [AutofillHints.nickname],
                            ),
                            const SizedBox(height: 10),
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
                              autofillHints: const [AutofillHints.email],
                              validator: FormValidators.email,
                            ),
                            const SizedBox(height: 10),
                            AppTextField(
                              label: 'Password',
                              icon: AppIcons.lock,
                              controller: _passwordController,
                              focusNode: _passwordFocus,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) =>
                                  _confirmFocus.requestFocus(),
                              onChanged: (_) => setState(() {}),
                              autofillHints: const [AutofillHints.newPassword],
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
                            if (_passwordController.text.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _PasswordStrength(
                                password: _passwordController.text,
                              ),
                            ],
                            const SizedBox(height: 10),
                            AppTextField(
                              label: 'Conferma password',
                              icon: AppIcons.lock,
                              controller: _confirmController,
                              focusNode: _confirmFocus,
                              obscureText: _obscureConfirm,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              validator: _validateConfirm,
                              suffix: IconButton(
                                tooltip: _obscureConfirm
                                    ? 'Mostra password'
                                    : 'Nascondi password',
                                icon: Icon(
                                  _obscureConfirm
                                      ? AppIcons.hidden
                                      : AppIcons.visible,
                                  size: 20,
                                ),
                                onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm,
                                ),
                              ),
                            ),
                            if (!session.firebaseReady) ...[
                              const SizedBox(height: 12),
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
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Termini e pulsante in un pannello verde chiaro in fondo
                    // al modulo (non fisso: con la tastiera aperta
                    // ruberebbe metà schermo).
                    Container(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        12,
                        16,
                        12 + bottomInset,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.greenLight,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Obbligatorio (GDPR e Google Play): senza
                          // accettazione il form non è valido.
                          FormField<bool>(
                            initialValue: _termsAccepted,
                            validator: (v) => v == true
                                ? null
                                : 'Per registrarti devi accettare termini e '
                                      'privacy',
                            builder: (field) => _TermsCheckbox(
                              value: field.value ?? false,
                              errorText: field.errorText,
                              onChanged: (v) {
                                field.didChange(v);
                                _termsAccepted = v;
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          AppButton(
                            label: _busy
                                ? 'Registrazione in corso…'
                                : 'Registrati',
                            icon: AppIcons.userAdd,
                            height: 58,
                            loading: _busy,
                            onPressed: session.firebaseReady ? _submit : null,
                          ),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text(
                                'Hai già un account?',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => context.canPop()
                                          ? context.pop()
                                          : context.go(AppRoutes.login),
                                child: const Text('Torna al login'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Ogni gesto conta": quanto valgono segnalazioni e pulizie.
class _PointsBanner extends StatelessWidget {
  const _PointsBanner();

  @override
  Widget build(BuildContext context) {
    Widget pill(int points) => Container(
      height: 22,
      padding: const EdgeInsets.only(left: 6, right: 8),
      decoration: BoxDecoration(
        color: AppColors.yellow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(AppIcons.starFilled, size: 12, color: AppColors.onYellow),
          const SizedBox(width: 3),
          Text(
            '+$points pt',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.onYellow,
            ),
          ),
        ],
      ),
    );
    const caption = TextStyle(
      fontSize: 12,
      height: 22 / 12,
      color: AppColors.greenDark,
    );

    // Altezza minima: con il testo ingrandito le pillole vanno a capo.
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.greenLight,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  const Text(
                    'Ogni gesto conta',
                    style: TextStyle(
                      fontSize: 14,
                      height: 18 / 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.greenDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 5,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      pill(pointsPerReport),
                      const Text('segnalazione', style: caption),
                      pill(pointsPerCleanup),
                      const Text('pulizia', style: caption),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 96,
            height: 76,
            child: SvgPicture.asset(
              'assets/onboarding/pulisci.svg',
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra a quattro tacche sotto la password, con un giudizio a parole.
class _PasswordStrength extends StatelessWidget {
  const _PasswordStrength({required this.password});

  final String password;

  int get _score {
    var score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[A-Z]').hasMatch(password)) {
      score++;
    }
    if (RegExp(r'\d').hasMatch(password)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;
    return score.clamp(1, 4);
  }

  @override
  Widget build(BuildContext context) {
    final score = _score;
    final (label, color) = switch (score) {
      1 => ('Password debole', AppColors.redText),
      2 => ('Password discreta', AppColors.amberText),
      3 => ('Password buona', AppColors.greenDark),
      _ => ('Password ottima', AppColors.greenDark),
    };
    final barColor = switch (score) {
      1 => AppColors.redPin,
      2 => AppColors.amberDot,
      _ => AppColors.greenBrand,
    };
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 5,
                  decoration: BoxDecoration(
                    color: i < score ? barColor : AppColors.mintBorder,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Ho letto e accetto i Termini d'uso e l'Informativa privacy", con i due
/// link apribili.
class _TermsCheckbox extends StatefulWidget {
  const _TermsCheckbox({
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? errorText;

  @override
  State<_TermsCheckbox> createState() => _TermsCheckboxState();
}

class _TermsCheckboxState extends State<_TermsCheckbox> {
  // Link come TextSpan con riconoscitore, non WidgetSpan: un widget dentro
  // il testo viene ingrandito due volte con il testo di sistema grande, e i
  // link risultavano più grossi del resto della frase.
  late final _termsTap = TapGestureRecognizer()
    ..onTap = () => LegalLinks.open(LegalLinks.terms);
  late final _privacyTap = TapGestureRecognizer()
    ..onTap = () => LegalLinks.open(LegalLinks.privacy);

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final onChanged = widget.onChanged;
    final errorText = widget.errorText;
    const style = TextStyle(
      fontSize: 13,
      height: 19 / 13,
      color: AppColors.greenDark,
    );
    final linkStyle = style.copyWith(
      color: AppColors.greenBrand,
      fontWeight: FontWeight.w800,
      decoration: TextDecoration.underline,
    );

    TextSpan link(String label, TapGestureRecognizer recognizer) =>
        TextSpan(text: label, style: linkStyle, recognizer: recognizer);

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
                      link('Termini d\'uso', _termsTap),
                      const TextSpan(text: ' e l\''),
                      link('Informativa privacy', _privacyTap),
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
              errorText,
              style: const TextStyle(
                color: AppColors.redText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
