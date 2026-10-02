import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../core/geo_utils.dart';
import '../core/geohash.dart';

/// Notifiche push (Firebase Cloud Messaging).
///
/// - registra il token del dispositivo in `users/{uid}/devices/{token}`,
///   da cui le Cloud Functions (functions/index.js) leggono a chi inviare;
/// - salva in `users/{uid}/notifyPrefs/settings` la preferenza "vicino a me"
///   e una posizione **approssimativa** (~1 km) dell'utente;
/// - gestisce il tocco sulla notifica (apre la segnalazione) e le notifiche
///   ricevute ad app aperta.
class PushService {
  PushService._();

  static final instance = PushService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseMessaging get _fcm => FirebaseMessaging.instance;

  String? _uid;
  String? _token;
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  ({double lat, double lng})? _lastSavedPosition;

  /// Chiamato quando si tocca una notifica: riceve l'id della segnalazione.
  void Function(String reportId)? onOpenReport;

  /// Notifica ricevuta con l'app in primo piano (Android non la mostra).
  void Function(String title, String body)? onForegroundMessage;

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Da chiamare quando l'utente è dentro l'app (dopo login e onboarding):
  /// chiede il permesso (Android 13+) e registra il dispositivo.
  Future<void> register(String uid) async {
    if (!_supported || _uid == uid) return;
    _uid = uid;
    try {
      final settings = await _fcm.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }
      final token = await _fcm.getToken();
      if (token != null) await _saveToken(token);
      await _tokenSub?.cancel();
      _tokenSub = _fcm.onTokenRefresh.listen(_saveToken);
      await _ensurePrefs();

      await _foregroundSub?.cancel();
      _foregroundSub = FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n != null) onForegroundMessage?.call(n.title ?? '', n.body ?? '');
      });
      await _openedSub?.cancel();
      _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(_handleOpen);
      final initial = await _fcm.getInitialMessage();
      if (initial != null) _handleOpen(initial);
    } catch (e) {
      debugPrint('Registrazione notifiche non riuscita: $e');
    }
  }

  void _handleOpen(RemoteMessage message) {
    final reportId = message.data['reportId'];
    if (reportId is String && reportId.isNotEmpty) onOpenReport?.call(reportId);
  }

  Future<void> _saveToken(String token) async {
    final uid = _uid;
    if (uid == null) return;
    if (_token != null && _token != token) {
      await _deviceRef(uid, _token!).delete().catchError((_) {});
    }
    _token = token;
    await _deviceRef(uid, token).set({
      'platform': defaultTargetPlatform.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  DocumentReference<Map<String, dynamic>> _deviceRef(String uid, String t) =>
      _db.collection('users').doc(uid).collection('devices').doc(t);

  DocumentReference<Map<String, dynamic>> _prefsRef(String uid) =>
      _db.collection('users').doc(uid).collection('notifyPrefs').doc('settings');

  /// Crea le preferenze al primo accesso: "vicino a me" attivo di default.
  Future<void> _ensurePrefs() async {
    final uid = _uid;
    if (uid == null) return;
    final ref = _prefsRef(uid);
    if (!(await ref.get()).exists) {
      await ref.set({'nearby': true, 'updatedAt': FieldValue.serverTimestamp()});
    }
  }

  /// Da chiamare prima del logout: il dispositivo smette di ricevere le
  /// notifiche di questo account. Dopo il logout le regole non lo
  /// permetterebbero più.
  Future<void> unregister() async {
    final uid = _uid;
    final token = _token;
    _uid = null;
    _token = null;
    _lastSavedPosition = null;
    await _tokenSub?.cancel();
    await _foregroundSub?.cancel();
    await _openedSub?.cancel();
    _tokenSub = _foregroundSub = _openedSub = null;
    if (uid == null || token == null) return;
    try {
      await _deviceRef(uid, token).delete();
      await _fcm.deleteToken();
    } catch (e) {
      debugPrint('Rimozione token notifiche non riuscita: $e');
    }
  }

  Stream<bool> watchNearbyEnabled(String uid) => _prefsRef(
    uid,
  ).snapshots().map((s) => s.data()?['nearby'] as bool? ?? true);

  Future<void> setNearbyEnabled(String uid, bool enabled) {
    return _prefsRef(uid).set({
      'nearby': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Aggiorna la posizione usata per "nuova segnalazione vicino a te".
  /// Arrotondata a 2 decimali (~1 km) e scritta solo se l'utente si è
  /// spostato di almeno 1 km, per privacy e per non sprecare scritture.
  Future<void> updateApproximateLocation(double latitude, double longitude) async {
    final uid = _uid;
    if (uid == null) return;
    double round(double v) => (v * 100).roundToDouble() / 100;
    final lat = round(latitude);
    final lng = round(longitude);
    final last = _lastSavedPosition;
    if (last != null && haversineKm(last.lat, last.lng, lat, lng) < 1) return;
    _lastSavedPosition = (lat: lat, lng: lng);
    try {
      await _prefsRef(uid).set({
        'latitude': lat,
        'longitude': lng,
        'geohash': geohashForLocation(lat, lng, precision: 7),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      _lastSavedPosition = last;
      debugPrint('Aggiornamento posizione notifiche non riuscito: $e');
    }
  }

  /// Usato all'eliminazione dell'account.
  Future<void> deleteUserData(String uid) async {
    for (final name in ['devices', 'notifyPrefs', 'notifications']) {
      final docs = await _db.collection('users').doc(uid).collection(name).get();
      for (final d in docs.docs) {
        await d.reference.delete();
      }
    }
  }
}

