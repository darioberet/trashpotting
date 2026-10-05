import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../models/leaderboard_entry.dart';
import '../repositories/leaderboard_repository.dart';
import '../repositories/report_repository.dart';
import 'notifier_message_mixin.dart';

class ClassificaViewModel extends ChangeNotifier with NotifierMessageMixin {
  ClassificaViewModel({
    required LeaderboardRepository repository,
    ReportRepository? reportRepository,
  }) : _repository = repository,
       _reportRepository = reportRepository ?? FirestoreReportRepository();

  final LeaderboardRepository _repository;
  final ReportRepository _reportRepository;

  List<LeaderboardEntry> _entries = const [];
  Map<String, int> _reportCounts = const {};
  bool _loading = false;
  bool _loaded = false;
  ({int points, int rank, int? reports})? _me;

  @override
  String get lastErrorFallback =>
      'Classifica non disponibile. Riprova più tardi.';

  List<LeaderboardEntry> get entries => _entries;
  bool get loading => _loading;
  bool get loaded => _loaded;

  /// Numero di segnalazioni dell'utente [uid], o null se non ancora caricato.
  int? reportCountFor(String uid) => _reportCounts[uid];

  /// Punti, posizione e segnalazioni dell'utente corrente, anche se è fuori
  /// dai primi della classifica. Null finché non è caricato.
  ({int points, int rank, int? reports})? get me => _me;

  Future<void> load({String? uid}) async {
    _loading = true;
    notifyListeners();

    try {
      _entries = await _repository.fetchTop();
      _loaded = true;
      notifyListeners();
      await Future.wait([_loadReportCounts(), if (uid != null) _loadMe(uid)]);
    } catch (e) {
      setError(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadMe(String uid) async {
    try {
      final listed = _entries.where((e) => e.uid == uid).firstOrNull;
      final points = listed?.points ?? await _repository.fetchUserPoints(uid);
      final rank = listed?.rank ?? await _repository.fetchRankForPoints(points);
      int? reports = _reportCounts[uid];
      try {
        reports ??= await _reportRepository.countByUser(uid);
      } catch (_) {}
      _me = (points: points, rank: rank, reports: reports);
      notifyListeners();
    } catch (_) {
      // Senza la propria riga la classifica resta comunque consultabile.
    }
  }

  Future<void> _loadReportCounts() async {
    try {
      final counts = await Future.wait(
        _entries.map(
          (e) async =>
              MapEntry(e.uid, await _reportRepository.countByUser(e.uid)),
        ),
      );
      _reportCounts = Map.fromEntries(counts);
      notifyListeners();
    } catch (_) {
      // Il conteggio segnalazioni è un dettaglio secondario: se fallisce,
      // la classifica resta comunque utilizzabile senza quel dato.
    }
  }
}
