import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.read,
    this.type,
    this.reportId,
  });

  final String id;
  final String title;
  final String body;
  final DateTime? createdAt;
  final bool read;

  /// `report_cleaned`, `event_reminder`, `nearby_report` (functions/index.js).
  final String? type;

  /// Segnalazione da aprire al tocco, se la notifica ne riguarda una.
  final String? reportId;

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final ts = d['createdAt'];
    DateTime? at;
    if (ts is Timestamp) {
      at = ts.toDate();
    }
    return AppNotification(
      id: doc.id,
      title: d['title'] as String? ?? 'Senza titolo',
      body: d['body'] as String? ?? '',
      createdAt: at,
      read: d['read'] as bool? ?? false,
      type: d['type'] as String?,
      reportId: d['reportId'] as String?,
    );
  }
}
