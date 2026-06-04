import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'routes.dart';
import 'screens/debug_firebase_screen.dart';
import 'screens/main_shell.dart';
import 'screens/notifiche_screen.dart';
import 'state/app_session.dart';

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
      initialLocation: AppRoutes.mappa,
      routes: [
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
          path: AppRoutes.debugFirebase,
          builder: (context, state) => DebugFirebaseScreen(),
        ),
      ],
      errorBuilder: (context, state) => const MainShell(),
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
          backgroundColor: message.isError ? null : Colors.green.shade700,
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
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2E7D32),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        ),
      ),
    );
  }
}
