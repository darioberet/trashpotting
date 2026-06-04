import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/report_draft.dart';

abstract class ReportRepository {
  Future<void> submitReport({required ReportDraft draft, String? uid});
}

class FirestoreReportRepository implements ReportRepository {
  FirestoreReportRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

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
