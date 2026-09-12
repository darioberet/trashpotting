import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'routes.dart';
import 'screens/debug_firebase_screen.dart';
import 'screens/email_verification_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/notifiche_screen.dart';
import 'screens/register_screen.dart';
import 'screens/report_detail_screen.dart';
import 'state/app_session.dart';
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
  int _lastMessageToken = -1;

  @override
  void initState() {
    super.initState();
    _session = AppSession(
      firebaseReady: widget.firebaseReady,
      firebaseError: widget.firebaseError,
    );
    _session.addListener(_onSessionChanged);
    _router = GoRouter(
      initialLocation: AppRoutes.login,
      refreshListenable: _session,
      redirect: (context, state) {
        final location = state.matchedLocation;
        final isAuthRoute =
            location == AppRoutes.login || location == AppRoutes.register;
        final isVerifyRoute = location == AppRoutes.emailVerification;
        final isPublicRoute =
            isAuthRoute || isVerifyRoute || location == AppRoutes.debugFirebase;
        final isSignedIn = _session.currentUserId != null;
        final emailVerified = _session.emailVerified;

        if (!isSignedIn && !isPublicRoute) return AppRoutes.login;
        if (isSignedIn && isAuthRoute) {
          return emailVerified ? AppRoutes.mappa : AppRoutes.emailVerification;
        }
        if (isSignedIn && !emailVerified && !isVerifyRoute) {
          return AppRoutes.emailVerification;
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
          builder: (context, state) => ReportDetailScreen(
            reportId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: AppRoutes.debugFirebase,
          builder: (context, state) => DebugFirebaseScreen(),
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

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppSessionScope(
      session: _session,
      child: MaterialApp.router(
        title: 'Trashpotting',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: _messengerKey,
        routerConfig: _router,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
      ),
    );
  }
}
