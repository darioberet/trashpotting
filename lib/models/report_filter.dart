import 'trashpot_report.dart';

/// Raggi di ricerca selezionabili nella pagina Mappa (km).
const reportRadiusOptionsKm = [1, 5, 10, 25, 50];
const defaultReportRadiusKm = 10;

/// Raggruppamento degli stati per i filtri: i sette stati del modello sono
/// troppi da mostrare singolarmente, per l'utente contano quattro fasi.
enum ReportStatusGroup {
  daPulire('Da pulire'),
  inCorso('In corso'),
  evento('Evento'),
  pulite('Pulite');

  const ReportStatusGroup(this.label);

  final String label;

  /// Valori del campo `status` su Firestore per questo gruppo: la query della
  /// mappa filtra su questi, così gli stati esclusi non vengono letti.
  List<String> get firestoreStatuses => switch (this) {
    daPulire => const ['segnalata', 'aperta'],
    inCorso => const ['inLavorazione', 'puliziaInCorso'],
    evento => const ['eventoCreato'],
    pulite => const ['ripulita', 'pulita'],
  };

  /// Null per le segnalazioni "sparite", che non appartengono a nessun
  /// gruppo e quindi non compaiono mai sulla mappa.
  static ReportStatusGroup? of(TrashpotStatus status) {
    return switch (status) {
      TrashpotStatus.segnalata || TrashpotStatus.aperta => daPulire,
      TrashpotStatus.inLavorazione || TrashpotStatus.puliziaInCorso => inCorso,
      TrashpotStatus.eventoCreato => evento,
      TrashpotStatus.pulita || TrashpotStatus.ripulita => pulite,
      TrashpotStatus.sparita => null,
    };
  }
}

/// Le segnalazioni ripulite restano sulla mappa solo per questo periodo:
/// dopo non servono più a chi cerca rifiuti da pulire e, accumulandosi,
/// sarebbero la maggior parte delle letture (e del costo) di Firestore.
const cleanedVisibleDays = 30;

/// Tetto alle ripulite recenti lette per ogni apertura della mappa.
const cleanedQueryLimit = 100;

/// Di base si vede tutto (chip "Tutti"): le ripulite sono comunque limitate
/// a [cleanedVisibleDays] giorni e [cleanedQueryLimit] documenti.
const defaultReportStatusGroups = {...ReportStatusGroup.values};
