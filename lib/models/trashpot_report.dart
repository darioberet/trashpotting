/// Stato segnalazione (allineato al prototipo web).
enum TrashpotStatus {
  aperta,
  inLavorazione,
  pulita,
  segnalata,
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
}

String trashpotStatusLabel(TrashpotStatus s) {
  return switch (s) {
    TrashpotStatus.aperta => 'Aperta',
    TrashpotStatus.inLavorazione => 'In lavorazione',
    TrashpotStatus.pulita => 'Pulita',
    TrashpotStatus.segnalata => 'Segnalata',
  };
}
