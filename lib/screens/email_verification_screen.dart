import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../repositories/user_profile_repository.dart';
import '../routes.dart';
import '../services/auth_service.dart';
import '../state/app_session.dart';
import '../theme/app_colors.dart';

class EmailVerificationScreen extends StatefulWidget {
  EmailVerificationScreen({
    super.key,
    AuthService? authService,
    UserProfileRepository? userProfileRepository,
  }) : _authService = authService ?? AuthService(),
       _userProfileRepository =
           userProfileRepository ?? UserProfileRepository();

  final AuthService _authService;
  final UserProfileRepository _userProfileRepository;

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
        // Trigger session refresh — AppSession listens to authStateChanges which
        // doesn't fire on email-verification; we force it by signing out and back
        // in is not ideal, so instead we just navigate and let the guard handle it.
        final uid = AppSessionScope.of(context).currentUserId;
        var onboarded = true;
        if (uid != null) {
          try {
            onboarded = await widget._userProfileRepository
                .hasCompletedOnboarding(uid);
          } catch (_) {
            // Non bloccare un utente già verificato per un errore di rete:
            // meglio farlo entrare (onboarding al più si ripresenterà).
          }
        }
        if (!mounted) return;
        context.go(onboarded ? AppRoutes.mappa : AppRoutes.onboarding);
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

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.greenLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mark_email_unread_outlined,
                      size: 36,
                      color: AppColors.greenBrand,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Verifica la tua email',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Abbiamo inviato un link di verifica a\n$email\n\nClicca il link nell\'email per attivare il tuo account.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _checking ? null : () => _checkVerified(),
                    icon: _checking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(
                      _checking
                          ? 'Verifica in corso...'
                          : 'Ho verificato la mia email',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _resending ? null : _resend,
                    icon: _resending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: Text(
                      _resending ? 'Invio in corso...' : 'Reinvia email',
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: _signOut,
                    child: const Text(
                      'Torna al login',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
