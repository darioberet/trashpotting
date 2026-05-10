import '../models/trashpot_report.dart';

/// Posizione demo utente (Ancona centro).
const double kDemoUserLat = 43.6158;
const double kDemoUserLng = 13.5189;

final List<TrashpotReport> mockTrashpots = [
  const TrashpotReport(
    id: '1',
    title: 'Discarica abusiva via Flaminia',
    address: 'Via Flaminia, 34 — Ancona',
    status: TrashpotStatus.aperta,
    lat: 43.615,
    lng: 13.518,
    distanceLabel: '0.3 km',
    dateLabel: '18 Apr 2026',
    typeLabel: 'Ingombranti',
  ),
  const TrashpotReport(
    id: '2',
    title: 'Rifiuti lungo il lungomare',
    address: 'Lungomare Vanvitelli, 12 — Ancona',
    status: TrashpotStatus.inLavorazione,
    lat: 43.608,
    lng: 13.512,
    distanceLabel: '0.7 km',
    dateLabel: '17 Apr 2026',
    typeLabel: 'Rifiuti generici',
  ),
  const TrashpotReport(
    id: '3',
    title: 'Pneumatici abbandonati',
    address: 'Via Mattei, 5 — Ancona',
    status: TrashpotStatus.pulita,
    lat: 43.620,
    lng: 13.525,
    distanceLabel: '1.1 km',
    dateLabel: '15 Apr 2026',
    typeLabel: 'Ingombranti',
  ),
  const TrashpotReport(
    id: '4',
    title: 'Materiali pericolosi in cantiere abbandonato',
    address: 'Via Marche, 88 — Ancona',
    status: TrashpotStatus.segnalata,
    lat: 43.625,
    lng: 13.510,
    distanceLabel: '1.5 km',
    dateLabel: '14 Apr 2026',
    typeLabel: 'Materiali pericolosi',
  ),
  const TrashpotReport(
    id: '5',
    title: 'Borse e scatole su Via Roma',
    address: 'Via Roma, 22 — Ancona',
    status: TrashpotStatus.aperta,
    lat: 43.612,
    lng: 13.520,
    distanceLabel: '0.5 km',
    dateLabel: '16 Apr 2026',
    typeLabel: 'Rifiuti generici',
  ),
];
