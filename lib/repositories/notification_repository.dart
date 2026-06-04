import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_notification.dart';

abstract class NotificationRepository {
  Stream<List<AppNotification>> watchUserNotifications(String uid);
  Future<void> markRead({required String uid, required String notificationId});
}

class FirestoreNotificationRepository implements NotificationRepository {
  FirestoreNotificationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<AppNotification>> watchUserNotifications(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(AppNotification.fromDoc).toList());
  }

  @override
  Future<void> markRead({required String uid, required String notificationId}) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }
}
