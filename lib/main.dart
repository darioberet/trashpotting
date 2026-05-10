import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var firebaseReady = false;
  Object? firebaseError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
  } catch (e, st) {
    firebaseError = e;
    if (kDebugMode) {
      debugPrint('Firebase.initializeApp failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  runApp(
    TrashpottingApp(
      firebaseReady: firebaseReady,
      firebaseError: firebaseError,
    ),
  );
}
