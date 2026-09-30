import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/geo_utils.dart';
import '../core/geohash.dart';
import '../models/app_user_profile.dart';
import '../models/report_draft.dart';
import '../models/trashpot_report.dart';

abstract class ReportRepository {
  Future<void> submitReport({required ReportDraft draft, String? uid});
  Future<void> anonymizeUserReports(String uid);
  Future<int> countByUser(String uid);
  Stream<List<TrashpotReport>> watchReports({int limit = 50});

  /// Segnalazioni entro [radiusKm] dal punto indicato, ordinate dalla più
  /// vicina.
  Stream<List<TrashpotReport>> watchReportsNear({
    required double latitude,
    required double longitude,
    required double radiusKm,
  });
  Stream<List<TrashpotReport>> watchReportsByUser(String uid, {int limit = 50});
  Stream<TrashpotReport?> watchReport(String reportId);
  Future<void> startCleaning({
    required String reportId,
    required AppUserProfile actor,
  });
  Future<void> completeCleaning({
    required String reportId,
    required AppUserProfile actor,
    required String cleanupPhotoUrl,
  });
  Future<void> scheduleCleanupEvent({
    required String reportId,
    required AppUserProfile creator,
    required DateTime scheduledAt,
  });
  Future<void> joinCleanupEvent({
    required String reportId,
    required AppUserProfile participant,
  });
}

class FirestoreReportRepository implements ReportRepository {
  FirestoreReportRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Tetto di documenti per ciascun range geohash, per non scaricare
  /// un'intera città in zone molto dense.
  static const _nearQueryLimit = 200;

  List<TrashpotReport> _parseDocs(QuerySnapshot<Map<String, dynamic>> snap) {
    return snap.docs
        .map((doc) {
          try {
            return TrashpotReport.fromDoc(doc);
          } catch (_) {
            return null;
          }
        })
        .whereType<TrashpotReport>()
        .toList();
  }

  @override
  Stream<List<TrashpotReport>> watchReportsNear({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) {
    final reports = _firestore.collection('reports');
    final queries = [
      for (final (start, end) in geohashQueryBounds(
        latitude,
        longitude,
        radiusKm * 1000,
      ))
        reports
            .orderBy('geohash')
            .startAt([start])
            .endAt([end])
            .limit(_nearQueryLimit)
            .snapshots()
            .map(_parseDocs),
      // Le segnalazioni create prima dell'introduzione del campo `geohash`
      // non compaiono nei range: finché non sono migrate
      // (tool/backfill_geohash.js) le recuperiamo tra le più recenti.
      reports
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .map(
            (snap) => _parseDocs(snap).where((r) => r.geohash == null).toList(),
          ),
    ];

    return _combineLatest(queries).map((lists) {
      final byId = <String, TrashpotReport>{};
      final distances = <String, double>{};
      for (final report in lists.expand((l) => l)) {
        final km = haversineKm(latitude, longitude, report.lat, report.lng);
        if (km > radiusKm) continue;
        byId[report.id] = report;
        distances[report.id] = km;
      }
      return byId.values.toList()
        ..sort((a, b) => distances[a.id]!.compareTo(distances[b.id]!));
    });
  }

  /// Emette l'ultimo valore di ogni stream, dopo che tutti hanno emesso
  /// almeno una volta (evita liste parziali durante il primo caricamento).
  static Stream<List<T>> _combineLatest<T>(List<Stream<T>> streams) {
    late final StreamController<List<T>> controller;
    final subscriptions = <StreamSubscription<T>>[];
    final latest = List<T?>.filled(streams.length, null);
    final hasValue = List<bool>.filled(streams.length, false);

    controller = StreamController<List<T>>(
      onListen: () {
        for (var i = 0; i < streams.length; i++) {
          subscriptions.add(
            streams[i].listen((value) {
              latest[i] = value;
              hasValue[i] = true;
              if (hasValue.every((v) => v)) {
                controller.add(List<T>.from(latest));
              }
            }, onError: controller.addError),
          );
        }
      },
      onCancel: () async {
        for (final sub in subscriptions) {
          await sub.cancel();
        }
        subscriptions.clear();
      },
    );
    return controller.stream;
  }

  @override
  Stream<List<TrashpotReport>> watchReports({int limit = 50}) {
    return _firestore
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) {
                try {
                  return TrashpotReport.fromDoc(doc);
                } catch (_) {
                  return null;
                }
              })
              .whereType<TrashpotReport>()
              .toList(),
        );
  }

  @override
  Stream<List<TrashpotReport>> watchReportsByUser(
    String uid, {
    int limit = 50,
  }) {
    return _firestore
        .collection('reports')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) {
                try {
                  return TrashpotReport.fromDoc(doc);
                } catch (_) {
                  return null;
                }
              })
              .whereType<TrashpotReport>()
              .toList(),
        );
  }

  @override
  Stream<TrashpotReport?> watchReport(String reportId) {
    return _firestore.collection('reports').doc(reportId).snapshots().map((
      doc,
    ) {
      if (!doc.exists) {
        return null;
      }

      try {
        return TrashpotReport.fromDoc(doc);
      } catch (_) {
        return null;
      }
    });
  }

  @override
  Future<int> countByUser(String uid) async {
    final snap = await _firestore
        .collection('reports')
        .where('uid', isEqualTo: uid)
        .count()
        .get();
    return snap.count ?? 0;
  }

  @override
  Future<void> anonymizeUserReports(String uid) async {
    final snap = await _firestore
        .collection('reports')
        .where('uid', isEqualTo: uid)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'uid': null});
    }
    await batch.commit();
  }

  @override
  Future<void> submitReport({required ReportDraft draft, String? uid}) {
    return _firestore.collection('reports').add({
      'note': draft.note,
      'photoUrl': draft.photoUrl,
      'latitude': draft.latitude,
      'longitude': draft.longitude,
      if (draft.latitude != null && draft.longitude != null)
        'geohash': geohashForLocation(draft.latitude!, draft.longitude!),
      'uid': uid,
      'status': 'segnalata',
      'type': draft.type,
      'address': draft.address,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> startCleaning({
    required String reportId,
    required AppUserProfile actor,
  }) async {
    final ref = _firestore.collection('reports').doc(reportId);
    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(ref);
      if (!snapshot.exists) {
        throw StateError('Report non trovato.');
      }

      final report = TrashpotReport.fromDoc(snapshot);
      final eventCreatorUid = report.event?.creator.uid;
      final cleaningOwnerUid = report.cleaningOwner?.uid;

      if (eventCreatorUid != null && eventCreatorUid != actor.uid) {
        throw StateError(
          'Solo chi ha creato l evento puo iniziare la pulizia.',
        );
      }
      if (cleaningOwnerUid != null && cleaningOwnerUid != actor.uid) {
        throw StateError('La pulizia e gia in carico a un altro utente.');
      }

      tx.update(ref, {
        'status': 'puliziaInCorso',
        'cleaningOwner': actor.toMap(),
        'cleaningStartedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> completeCleaning({
    required String reportId,
    required AppUserProfile actor,
    required String cleanupPhotoUrl,
  }) async {
    final ref = _firestore.collection('reports').doc(reportId);
    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(ref);
      if (!snapshot.exists) {
        throw StateError('Report non trovato.');
      }

      final report = TrashpotReport.fromDoc(snapshot);
      if (report.cleaningOwner?.uid != actor.uid) {
        throw StateError(
          'Solo chi ha preso in carico la pulizia puo completarla.',
        );
      }

      tx.update(ref, {
        'status': 'ripulita',
        'cleanupPhotoUrl': cleanupPhotoUrl,
        'cleanedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> scheduleCleanupEvent({
    required String reportId,
    required AppUserProfile creator,
    required DateTime scheduledAt,
  }) async {
    final ref = _firestore.collection('reports').doc(reportId);
    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(ref);
      if (!snapshot.exists) {
        throw StateError('Report non trovato.');
      }

      final report = TrashpotReport.fromDoc(snapshot);
      if (report.event != null) {
        throw StateError('Esiste gia un evento attivo per questo report.');
      }

      tx.update(ref, {
        'status': 'eventoCreato',
        'event': {
          'creator': creator.toMap(),
          'scheduledAt': Timestamp.fromDate(scheduledAt),
          'participants': [creator.toMap()],
        },
      });
    });
  }

  @override
  Future<void> joinCleanupEvent({
    required String reportId,
    required AppUserProfile participant,
  }) async {
    final ref = _firestore.collection('reports').doc(reportId);
    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(ref);
      if (!snapshot.exists) {
        throw StateError('Report non trovato.');
      }

      final report = TrashpotReport.fromDoc(snapshot);
      final event = report.event;
      if (event == null) {
        throw StateError('Nessun evento disponibile per questo report.');
      }

      final participants = [...event.participants];
      final alreadyJoined = participants.any(
        (item) => item.uid == participant.uid,
      );
      if (!alreadyJoined) {
        participants.add(participant);
      }

      tx.update(ref, {
        'event': {
          'creator': event.creator.toMap(),
          'scheduledAt': Timestamp.fromDate(event.scheduledAt),
          'participants': participants.map((item) => item.toMap()).toList(),
        },
      });
    });
  }
}
