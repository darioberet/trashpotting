import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../routes.dart';
import '../services/auth_service.dart';
import '../state/app_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../widgets/app_button.dart';
import '../widgets/illustration.dart';

class EmailVerificationScreen extends StatefulWidget {
  EmailVerificationScreen({super.key, AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _checking = false;
  bool _resending = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    // Poll every 4 seconds — Firebase Auth doesn't push email-verified changes.
    _pollTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _checkVerified(silent: true),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerified({bool silent = false}) async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      await widget._authService.reloadCurrentUser();
      if (!mounted) return;
      if (widget._authService.currentUserEmailVerified) {
        // authStateChanges non notifica la verifica dell'email: va riallineata
        // la sessione a mano, altrimenti il redirect del router legge ancora
        // emailVerified == false e riporta a questa schermata.
        // Anche il flag di onboarding in sessione va riletto: il router
        // decide su quello, non sul valore letto qui. In caso di errore di
        // rete resta il valore ottimistico (l'utente entra comunque).
        final session = AppSessionScope.of(context)..refreshCurrentUser();
        await session.refreshOnboardingStatus();
        if (!mounted) return;
        context.go(
          session.onboardingComplete ? AppRoutes.mappa : AppRoutes.onboarding,
        );
      } else if (!silent) {
        AppSessionScope.of(context).publishInfo('Email non ancora verificata.');
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    if (_resending) return;
    setState(() => _resending = true);
    try {
      await widget._authService.sendEmailVerification();
      if (!mounted) return;
      AppSessionScope.of(
        context,
      ).publishInfo('Email di verifica inviata di nuovo.');
    } catch (e) {
      if (!mounted) return;
      AppSessionScope.of(
        context,
      ).publishError(e, fallback: 'Impossibile inviare l\'email di verifica.');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _signOut() async {
    await AuthService().signOut();
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSessionScope.watch(context);
    final email = session.currentUser?.email ?? '';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: IllustratedMessage(
              illustration: const Center(
                child: Icon(
                  AppIcons.emailUnread,
                  size: 96,
                  color: AppColors.greenBrand,
                ),
              ),
              badge: (
                icon: AppIcons.email,
                label: 'Ultimo passo',
                bg: AppColors.yellowLight,
                fg: AppColors.yellowText,
              ),
              title: 'Verifica la tua email',
              message: email.isEmpty
                  ? 'Ti abbiamo inviato un link di verifica. Aprilo per '
                        'attivare il tuo account.'
                  : 'Abbiamo inviato un link di verifica a $email. Aprilo '
                        'per attivare il tuo account.',
              note: const IllustratedNote(
                icon: AppIcons.info,
                text:
                    'Non la trovi? Controlla anche la cartella spam o '
                    'promozioni.',
                bg: AppColors.purpleLight,
                fg: AppColors.purpleDark,
              ),
              primary: AppButton(
                label: _checking
                    ? 'Verifica in corso…'
                    : 'Ho verificato la mia email',
                icon: AppIcons.check,
                loading: _checking,
                onPressed: () => _checkVerified(),
              ),
              secondary: [
                TextButton(
                  onPressed: _resending ? null : _resend,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.greenDark,
                  ),
                  child: Text(_resending ? 'Invio in corso…' : 'Reinvia email'),
                ),
                TextButton(
                  onPressed: _signOut,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text('Torna al login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
