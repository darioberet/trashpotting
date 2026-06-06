import 'package:cloud_firestore/cloud_firestore.dart';

/// Stato segnalazione (allineato al prototipo web).
enum TrashpotStatus { aperta, inLavorazione, pulita, segnalata }

/// Punto “trashpot” sulla mappa — segnalazione rifiuti.
class TrashpotReport {
  const TrashpotReport({
    required this.id,
    required this.title,
    required this.address,
    required this.status,
    required this.lat,
    required this.lng,
    this.distanceLabel,
    this.dateLabel,
    this.typeLabel,
  });

  final String id;
  final String title;
  final String address;
  final TrashpotStatus status;
  final double lat;
  final double lng;
  final String? distanceLabel;
  final String? dateLabel;
  final String? typeLabel;

  factory TrashpotReport.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final latitude = (data['latitude'] as num?)?.toDouble();
    final longitude = (data['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) {
      throw StateError('Report ${doc.id} senza coordinate valide.');
    }

    final createdAt = data['createdAt'];
    final createdDate = createdAt is Timestamp ? createdAt.toDate() : null;
    final rawNote = (data['note'] as String?)?.trim();

    return TrashpotReport(
      id: doc.id,
      title: rawNote?.isNotEmpty == true ? rawNote! : 'Segnalazione',
      address:
          data['address'] as String? ?? 'Posizione rilevata dal dispositivo',
      status: trashpotStatusFromString(data['status'] as String?),
      lat: latitude,
      lng: longitude,
      dateLabel: createdDate == null
          ? null
          : '${createdDate.day.toString().padLeft(2, '0')}/${createdDate.month.toString().padLeft(2, '0')}/${createdDate.year}',
      typeLabel: data['typeLabel'] as String? ?? data['type'] as String?,
    );
  }
}

TrashpotStatus trashpotStatusFromString(String? raw) {
  return switch (raw) {
    'aperta' => TrashpotStatus.aperta,
    'inLavorazione' || 'in_lavorazione' => TrashpotStatus.inLavorazione,
    'pulita' => TrashpotStatus.pulita,
    'segnalata' || null => TrashpotStatus.segnalata,
    _ => TrashpotStatus.segnalata,
  };
}

String trashpotStatusLabel(TrashpotStatus s) {
  return switch (s) {
    TrashpotStatus.aperta => 'Aperta',
    TrashpotStatus.inLavorazione => 'In lavorazione',
    TrashpotStatus.pulita => 'Pulita',
    TrashpotStatus.segnalata => 'Segnalata',
  };
}
