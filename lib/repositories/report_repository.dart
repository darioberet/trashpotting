import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/report_draft.dart';
import '../models/trashpot_report.dart';

abstract class ReportRepository {
  Future<void> submitReport({required ReportDraft draft, String? uid});
  Stream<List<TrashpotReport>> watchReports();
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
}
