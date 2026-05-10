// Generated configuration placeholder.
// Replace this file by running (from project root):
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// ignore_for_file: lines_longer_than_80_chars

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Until you run `flutterfire configure`, values are non-functional placeholders
/// so the project compiles; swap the generated file for real options.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos — '
          'run `flutterfire configure` or remove macos from your build targets.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows — '
          'run `flutterfire configure` or remove windows from your build targets.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux — '
          'run `flutterfire configure` or remove linux from your build targets.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBloMJQg6uTXwzmwX5OwYF_oNu9oW7vB5M',
    appId: '1:1059796102944:web:600233b1b7fe45092d3145',
    messagingSenderId: '1059796102944',
    projectId: 'trashpotting-app',
    authDomain: 'trashpotting-app.firebaseapp.com',
    storageBucket: 'trashpotting-app.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCGxhxOB8kExRrUdCIrLY_6AGFg6IYRHNw',
    appId: '1:1059796102944:android:56f262dbd56f926b2d3145',
    messagingSenderId: '1059796102944',
    projectId: 'trashpotting-app',
    storageBucket: 'trashpotting-app.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAwLEH_9NRt4DxpBNJw7Q6ZUT8f3DPy8VM',
    appId: '1:1059796102944:ios:83a3a5b05e8d322d2d3145',
    messagingSenderId: '1059796102944',
    projectId: 'trashpotting-app',
    storageBucket: 'trashpotting-app.firebasestorage.app',
    iosBundleId: 'com.trashpotting.trashpottingV3',
  );

}