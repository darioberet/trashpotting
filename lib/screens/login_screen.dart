import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../core/form_validators.dart';
import '../models/app_user_profile.dart';
import '../repositories/user_profile_repository.dart';
import '../routes.dart';
import '../services/auth_service.dart';
import '../state/app_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';

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
        await widget._userProfileRepository.ensureProfile(
          AppUserProfile.fromAuthUser(user),
        );
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
    final cs = Theme.of(context).colorScheme;
    final session = AppSessionScope.watch(context);

    return Scaffold(
      body: Column(
        children: [
          _WaveHeader(topInset: MediaQuery.of(context).padding.top),
          Expanded(
            child: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                    children: [
                      Text(
                        'Bentornato',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: context.palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Accedi per continuare a fare la differenza',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          color: context.palette.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 32),

                      Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                              decoration: InputDecoration(
                                hintText: 'Email',
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: SvgPicture.asset(
                                    'assets/icons/email.svg',
                                    colorFilter: const ColorFilter.mode(
                                      AppColors.greenBrand,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                ),
                              ),
                              validator: FormValidators.email,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordController,
                              focusNode: _passwordFocus,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              autofillHints: const [AutofillHints.password],
                              decoration: InputDecoration(
                                hintText: 'Password',
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  size: 18,
                                  color: AppColors.greenBrand,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 18,
                                    color: context.palette.textDisabled,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                              ),
                              validator: FormValidators.password,
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _showPasswordReset(context),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                  minimumSize: const Size(48, 48),
                                ),
                                child: const Text(
                                  'Password dimenticata?',
                                  style: TextStyle(
                                    fontSize: 12,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (!session.firebaseReady) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Firebase non disponibile. Controlla la configurazione.',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: cs.error),
                          textAlign: TextAlign.center,
                        ),
                      ],

                      const SizedBox(height: 20),

                      FilledButton(
                        onPressed: _busy || !session.firebaseReady
                            ? null
                            : _submit,
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

                      const SizedBox(height: 28),

                      Row(
                        children: [
                          Expanded(
                            child: Divider(color: context.palette.divider),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Icon(
                              Icons.eco_outlined,
                              size: 16,
                              color: AppColors.greenBrand,
                            ),
                          ),
                          Expanded(
                            child: Divider(color: context.palette.divider),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Wrap invece di Row: con testo ingrandito
                      // (accessibilità) o schermi stretti va a capo
                      // invece di sforare.
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Non hai un account? ',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontSize: 13,
                                  color: context.palette.textSecondary,
                                ),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => context.push(AppRoutes.register),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              minimumSize: const Size(48, 48),
                            ),
                            child: const Text(
                              'Registrati',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveHeader extends StatelessWidget {
  const _WaveHeader({required this.topInset});

  final double topInset;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _WaveBottomClipper(),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(24, topInset + 28, 24, 56),
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/login_header_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 64,
              height: 74,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  SvgPicture.asset(
                    'assets/icons/logo_leaf_pin.svg',
                    width: 56,
                    height: 56,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Icon(
                      Icons.eco,
                      size: 22,
                      color: AppColors.greenBrand,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    child: Container(
                      width: 26,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Trashpotting',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaveBottomClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()..lineTo(0, size.height - 36);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height,
      size.width * 0.5,
      size.height - 18,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height - 36,
      size.width,
      size.height - 8,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
