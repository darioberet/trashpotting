import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseHealthService {
  FirebaseHealthService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> probeWrite() {
    return _firestore
        .collection('_health')
        .doc('ping')
        .set({'at': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }
}
