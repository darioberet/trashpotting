import 'package:flutter/material.dart';

import 'routes.dart';
import 'screens/debug_firebase_screen.dart';
import 'screens/main_shell.dart';
import 'screens/notifiche_screen.dart';

class TrashpottingApp extends StatelessWidget {
  const TrashpottingApp({
    super.key,
    required this.firebaseReady,
    this.firebaseError,
  });

  final bool firebaseReady;
  final Object? firebaseError;

  int _tabIndexForRoute(String? name) {
    switch (name) {
      case AppRoutes.mappa:
        return 0;
      case AppRoutes.segnala:
        return 1;
      case AppRoutes.classifica:
        return 2;
      case AppRoutes.profilo:
        return 3;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trashpotting',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      ),
      initialRoute: AppRoutes.mappa,
      onGenerateRoute: (settings) {
        Widget page;
        switch (settings.name) {
          case AppRoutes.mappa:
          case AppRoutes.segnala:
          case AppRoutes.classifica:
          case AppRoutes.profilo:
            page = MainShell(
              firebaseReady: firebaseReady,
              firebaseError: firebaseError,
              initialIndex: _tabIndexForRoute(settings.name),
            );
            break;
          case AppRoutes.notifiche:
            page = NotificheScreen(
              firebaseReady: firebaseReady,
              firebaseError: firebaseError,
            );
            break;
          case AppRoutes.debugFirebase:
            page = DebugFirebaseScreen(
              firebaseReady: firebaseReady,
              firebaseError: firebaseError,
            );
            break;
          default:
            page = MainShell(
              firebaseReady: firebaseReady,
              firebaseError: firebaseError,
            );
        }
        return MaterialPageRoute<void>(
          builder: (_) => page,
          settings: settings,
        );
      },
    );
  }
}
