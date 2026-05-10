import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

Completer<void>? _androidMapsReadyOnce;

/// Chiamare sul primo utilizzo della mappa su Android: inizializza il renderer
/// e fa [warmup] del Maps SDK così parte del lavoro non avviene solo dentro
/// [MapView.onCreate] (meno blocchi sul main thread / log tipo ClientParamsBlocking).
Future<void> ensureAndroidMapsSdkReady() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

  final existing = _androidMapsReadyOnce;
  if (existing != null) return existing.future;

  final done = Completer<void>();
  _androidMapsReadyOnce = done;

  final impl = GoogleMapsFlutterPlatform.instance;
  if (impl is! GoogleMapsFlutterAndroid) {
    done.complete();
    return done.future;
  }

  try {
    await impl.initializeWithRenderer(AndroidMapRenderer.latest);
    await impl.warmup();
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('ensureAndroidMapsSdkReady failed (map may still work): $e');
      debugPrintStack(stackTrace: st);
    }
  } finally {
    if (!done.isCompleted) done.complete();
  }

  return done.future;
}
