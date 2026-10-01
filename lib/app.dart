import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'routes.dart';
import 'screens/aiuto_feedback_screen.dart';
import 'screens/debug_firebase_screen.dart';
import 'screens/email_verification_screen.dart';
import 'screens/impostazioni_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/mie_segnalazioni_screen.dart';
import 'screens/notifiche_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/register_screen.dart';
import 'screens/report_detail_screen.dart';
import 'state/app_session.dart';
import 'state/theme_controller.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

class TrashpottingApp extends StatefulWidget {
  const TrashpottingApp({
    super.key,
    required this.firebaseReady,
    this.firebaseError,
  });

  final bool firebaseReady;
  final Object? firebaseError;

  @override
  State<TrashpottingApp> createState() => _TrashpottingAppState();
}

class _TrashpottingAppState extends State<TrashpottingApp> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final AppSession _session;
  late final GoRouter _router;
  final _themeController = ThemeController();
  int _lastMessageToken = -1;

  @override
  void initState() {
    super.initState();
    _session = AppSession(
      firebaseReady: widget.firebaseReady,
      firebaseError: widget.firebaseError,
    );
    _session.addListener(_onSessionChanged);
    _themeController.addListener(_onThemeChanged);
    _themeController.load();
    _router = GoRouter(
      initialLocation: AppRoutes.login,
      refreshListenable: _session,
      // Solo tracking automatico delle schermate per ora, nessun evento
      // custom (a differenza di Crashlytics, Analytics supporta anche web).
      observers: [
        if (widget.firebaseReady)
          FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
      ],
      redirect: (context, state) {
        final location = state.matchedLocation;
        final isAuthRoute =
            location == AppRoutes.login || location == AppRoutes.register;
        final isVerifyRoute = location == AppRoutes.emailVerification;
        final isOnboardingRoute = location == AppRoutes.onboarding;
        final isPublicRoute =
            isAuthRoute || isVerifyRoute || location == AppRoutes.debugFirebase;
        final isSignedIn = _session.currentUserId != null;
        final emailVerified = _session.emailVerified;
        final onboarded = _session.onboardingComplete;

        if (!isSignedIn && !isPublicRoute) return AppRoutes.login;
        if (isSignedIn && isAuthRoute) {
          if (!emailVerified) return AppRoutes.emailVerification;
          return onboarded ? AppRoutes.mappa : AppRoutes.onboarding;
        }
        if (isSignedIn && !emailVerified && !isVerifyRoute) {
          return AppRoutes.emailVerification;
        }
        // Account nuovo non ancora onboardato: forza il flusso di
        // benvenuto/profilo prima di lasciarlo entrare nell'app.
        if (isSignedIn && emailVerified && !onboarded && !isOnboardingRoute) {
          return AppRoutes.onboarding;
        }
        // Onboarding già completato: niente replay se torna indietro.
        if (isSignedIn && emailVerified && onboarded && isOnboardingRoute) {
          return AppRoutes.mappa;
        }
        return null;
      },
      routes: [
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) => LoginScreen(),
        ),
        GoRoute(
          path: AppRoutes.register,
          builder: (context, state) => RegisterScreen(),
        ),
        GoRoute(
          path: AppRoutes.emailVerification,
          builder: (context, state) => EmailVerificationScreen(),
        ),
        GoRoute(
          path: AppRoutes.onboarding,
          builder: (context, state) => OnboardingScreen(),
        ),
        GoRoute(
          path: AppRoutes.mappa,
          builder: (context, state) => const MainShell(initialIndex: 0),
        ),
        GoRoute(
          path: AppRoutes.segnala,
          builder: (context, state) => const MainShell(initialIndex: 1),
        ),
        GoRoute(
          path: AppRoutes.classifica,
          builder: (context, state) => const MainShell(initialIndex: 2),
        ),
        GoRoute(
          path: AppRoutes.profilo,
          builder: (context, state) => const MainShell(initialIndex: 3),
        ),
        GoRoute(
          path: AppRoutes.notifiche,
          builder: (context, state) => NotificheScreen(),
        ),
        GoRoute(
          path: '${AppRoutes.reportDetail}/:id',
          builder: (context, state) =>
              ReportDetailScreen(reportId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: AppRoutes.debugFirebase,
          builder: (context, state) => DebugFirebaseScreen(),
        ),
        GoRoute(
          path: AppRoutes.impostazioni,
          builder: (context, state) => const ImpostazioniScreen(),
        ),
        GoRoute(
          path: AppRoutes.mieSegnalazioni,
          builder: (context, state) => MieSegnalazioniScreen(),
        ),
        GoRoute(
          path: AppRoutes.aiutoFeedback,
          builder: (context, state) => const AiutoFeedbackScreen(),
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link_off_outlined, size: 56),
                const SizedBox(height: 16),
                Text(
                  'Pagina non trovata',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  state.matchedLocation,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go(AppRoutes.mappa),
                  child: const Text('Vai alla mappa'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant TrashpottingApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.firebaseReady != oldWidget.firebaseReady ||
        widget.firebaseError != oldWidget.firebaseError) {
      _session.updateFirebaseState(
        ready: widget.firebaseReady,
        error: widget.firebaseError,
      );
    }
  }

  void _onSessionChanged() {
    final message = _session.message;
    if (message == null || message.token == _lastMessageToken) return;
    _lastMessageToken = message.token;
    _messengerKey.currentState
      ?..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message.text),
          backgroundColor: message.isError
              ? AppColors.redPin
              : AppColors.greenDark,
        ),
      );
  }

  void _onThemeChanged() => setState(() {});

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    _session.dispose();
    _themeController.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppSessionScope(
      session: _session,
      child: ThemeControllerScope(
        controller: _themeController,
        child: MaterialApp.router(
          title: 'Trashpotting',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: _messengerKey,
          routerConfig: _router,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: _themeController.mode,
          // L'app è solo in italiano: calendario, orologio e dialog Material
          // altrimenti comparirebbero in inglese ("Select date", "Cancel").
          locale: const Locale('it'),
          supportedLocales: const [Locale('it')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
        ),
      ),
    );
  }
}
