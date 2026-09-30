import 'trashpot_report.dart';

/// Raggi di ricerca selezionabili nella pagina Mappa (km).
const reportRadiusOptionsKm = [1, 5, 10, 25, 50];
const defaultReportRadiusKm = 10;

/// Raggruppamento degli stati per i filtri: i sette stati del modello sono
/// troppi da mostrare singolarmente, per l'utente contano tre fasi.
enum ReportStatusGroup {
  daPulire('Da pulire'),
  inCorso('In corso'),
  pulite('Pulite');

  const ReportStatusGroup(this.label);

  final String label;

  static ReportStatusGroup of(TrashpotStatus status) {
    return switch (status) {
      TrashpotStatus.segnalata || TrashpotStatus.aperta => daPulire,
      TrashpotStatus.inLavorazione ||
      TrashpotStatus.eventoCreato ||
      TrashpotStatus.puliziaInCorso => inCorso,
      TrashpotStatus.pulita || TrashpotStatus.ripulita => pulite,
    };
  }
}

const defaultReportStatusGroups = {
  ReportStatusGroup.daPulire,
  ReportStatusGroup.inCorso,
};
