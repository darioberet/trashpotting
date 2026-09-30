// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import 'app.dart';
import 'firebase_options.dart';

/// Avvio senza `await` su Firebase prima di [runApp]: così il motore può
/// dipingere il primo frame subito e Android/iOS tolgono lo splash nativo.
/// Se [Firebase.initializeApp] si blocca o è lentissima, prima l’app restava
/// inchiodata sulla schermata iniziale (logo Flutter).
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Su Android il default (texture layer hybrid composition) può chiamare
  // localToGlobal sul platform view prima che il layout sia completo → assert
  // hasSize su RenderFractionalTranslation. Hybrid Composition evita quel caso.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    final impl = GoogleMapsFlutterPlatform.instance;
    if (impl is GoogleMapsFlutterAndroid) {
      impl.useAndroidViewSurface = true;
    }
  }

  runApp(const _FirebaseBootstrap());
}

class _FirebaseBootstrap extends StatefulWidget {
  const _FirebaseBootstrap();

  @override
  State<_FirebaseBootstrap> createState() => _FirebaseBootstrapState();
}

class _FirebaseBootstrapState extends State<_FirebaseBootstrap> {
  static const _initTimeout = Duration(seconds: 15);

  bool _resolved = false;
  bool _firebaseReady = false;
  Object? _firebaseError;

  @override
  void initState() {
    super.initState();
    _initFirebase();
  }

  Future<void> _initFirebase() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(_initTimeout);
      await _activateAppCheck();
      _activateCrashReporting();
      _firebaseReady = true;
    } on TimeoutException catch (e, st) {
      _firebaseError = e;
      if (kDebugMode) {
        debugPrint('Firebase.initializeApp timed out after $_initTimeout');
        debugPrintStack(stackTrace: st);
      }
    } catch (e, st) {
      _firebaseError = e;
      if (kDebugMode) {
        debugPrint('Firebase.initializeApp failed: $e');
        debugPrintStack(stackTrace: st);
      }
    } finally {
      if (mounted) setState(() => _resolved = true);
    }
  }

  /// Crashlytics non ha implementazione web: niente da attivare lì. In
  /// debug teniamo la raccolta spenta per non sporcare la dashboard con gli
  /// errori di sviluppo, ma lasciamo comunque stampare in console.
  /// Non deve mai poter bloccare l'avvio: stesso trattamento di App Check.
  void _activateCrashReporting() {
    if (kIsWeb) return;

    try {
      FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);

      final previousOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        previousOnError?.call(details);
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Crashlytics activation failed: $e');
        debugPrintStack(stackTrace: st);
      }
    }
  }

  Future<void> _activateAppCheck() async {
    if (kIsWeb) return;

    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode
            ? AndroidProvider.debug
            : AndroidProvider.playIntegrity,
        appleProvider: kDebugMode
            ? AppleProvider.debug
            : AppleProvider.appAttestWithDeviceCheckFallback,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('FirebaseAppCheck.activate failed: $e');
        debugPrintStack(stackTrace: st);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_resolved) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2E7D32),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return TrashpottingApp(
      firebaseReady: _firebaseReady,
      firebaseError: _firebaseError,
    );
  }
}
