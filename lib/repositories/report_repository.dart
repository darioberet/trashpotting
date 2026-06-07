import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user_profile.dart';
import '../models/report_draft.dart';
import '../models/trashpot_report.dart';

abstract class ReportRepository {
  Future<void> submitReport({required ReportDraft draft, String? uid});
  Stream<List<TrashpotReport>> watchReports();
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

  @override
  Stream<List<TrashpotReport>> watchReports() {
    return _firestore
        .collection('reports')
        .orderBy('createdAt', descending: true)
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
  Future<void> submitReport({required ReportDraft draft, String? uid}) {
    return _firestore.collection('reports').add({
      'note': draft.note,
      'photoUrl': draft.photoUrl,
      'latitude': draft.latitude,
      'longitude': draft.longitude,
      'uid': uid,
      'status': 'segnalata',
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
