import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_user_profile.dart';

/// Stato segnalazione (allineato al prototipo web).
enum TrashpotStatus {
  aperta,
  inLavorazione,
  pulita,
  segnalata,
  eventoCreato,
  puliziaInCorso,
  ripulita,
}

class CleanupEvent {
  const CleanupEvent({
    required this.creator,
    required this.scheduledAt,
    required this.participants,
  });

  final AppUserProfile creator;
  final DateTime scheduledAt;
  final List<AppUserProfile> participants;

  Map<String, dynamic> toMap() {
    return {
      'creator': creator.toMap(),
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'participants': participants
          .map((participant) => participant.toMap())
          .toList(),
    };
  }

  factory CleanupEvent.fromMap(Map<String, dynamic> data) {
    final scheduledAtRaw = data['scheduledAt'];
    DateTime scheduledAt = DateTime.now();
    if (scheduledAtRaw is Timestamp) {
      scheduledAt = scheduledAtRaw.toDate();
    }

    final participantsRaw = data['participants'] as List<dynamic>? ?? const [];

    return CleanupEvent(
      creator: AppUserProfile.fromMap(
        Map<String, dynamic>.from(data['creator'] as Map? ?? const {}),
      ),
      scheduledAt: scheduledAt,
      participants: participantsRaw
          .whereType<Map>()
          .map(
            (entry) => AppUserProfile.fromMap(Map<String, dynamic>.from(entry)),
          )
          .toList(),
    );
  }
}

/// Punto “trashpot” sulla mappa — segnalazione rifiuti.
class TrashpotReport {
  const TrashpotReport({
    required this.id,
    required this.title,
    required this.address,
    required this.status,
    required this.lat,
    required this.lng,
    this.note,
    this.photoUrl,
    this.cleanupPhotoUrl,
    this.reporterUid,
    this.cleaningOwner,
    this.event,
    this.createdAt,
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
  final String? note;
  final String? photoUrl;
  final String? cleanupPhotoUrl;
  final String? reporterUid;
  final AppUserProfile? cleaningOwner;
  final CleanupEvent? event;
  final DateTime? createdAt;
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
    final cleaningOwnerRaw = data['cleaningOwner'];
    final eventRaw = data['event'];

    return TrashpotReport(
      id: doc.id,
      title: rawNote?.isNotEmpty == true ? rawNote! : 'Segnalazione',
      note: rawNote,
      address:
          data['address'] as String? ?? 'Posizione rilevata dal dispositivo',
      status: trashpotStatusFromString(data['status'] as String?),
      lat: latitude,
      lng: longitude,
      photoUrl: (data['photoUrl'] as String?)?.trim().isNotEmpty == true
          ? (data['photoUrl'] as String).trim()
          : null,
      cleanupPhotoUrl:
          (data['cleanupPhotoUrl'] as String?)?.trim().isNotEmpty == true
          ? (data['cleanupPhotoUrl'] as String).trim()
          : null,
      reporterUid: data['uid'] as String?,
      cleaningOwner: cleaningOwnerRaw is Map
          ? AppUserProfile.fromMap(Map<String, dynamic>.from(cleaningOwnerRaw))
          : null,
      event: eventRaw is Map
          ? CleanupEvent.fromMap(Map<String, dynamic>.from(eventRaw))
          : null,
      createdAt: createdDate,
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
    'eventoCreato' || 'evento_creato' => TrashpotStatus.eventoCreato,
    'puliziaInCorso' || 'pulizia_in_corso' => TrashpotStatus.puliziaInCorso,
    'ripulita' => TrashpotStatus.ripulita,
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
    TrashpotStatus.eventoCreato => 'Evento creato',
    TrashpotStatus.puliziaInCorso => 'Pulizia in corso',
    TrashpotStatus.ripulita => 'Ripulita',
  };
}
