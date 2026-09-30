import 'package:flutter/foundation.dart' show ChangeNotifier, kDebugMode;

import '../models/leaderboard_entry.dart';
import '../repositories/leaderboard_repository.dart';
import '../repositories/report_repository.dart';
import 'notifier_message_mixin.dart';

class ClassificaViewModel extends ChangeNotifier with NotifierMessageMixin {
  ClassificaViewModel({
    required LeaderboardRepository repository,
    ReportRepository? reportRepository,
    bool enableMockFallback = kDebugMode,
  }) : _repository = repository,
       _reportRepository = reportRepository ?? FirestoreReportRepository(),
       _enableMockFallback = enableMockFallback;

  final LeaderboardRepository _repository;
  final ReportRepository _reportRepository;
  final bool _enableMockFallback;

  List<LeaderboardEntry> _entries = const [];
  Map<String, int> _reportCounts = const {};
  bool _loading = false;
  bool _loaded = false;

  @override
  String get lastErrorFallback =>
      'Classifica non disponibile. Riprova più tardi.';

  List<LeaderboardEntry> get entries => _entries;
  bool get loading => _loading;
  bool get loaded => _loaded;

  /// Numero di segnalazioni dell'utente [uid], o null se non ancora caricato.
  int? reportCountFor(String uid) => _reportCounts[uid];

  Future<void> load() async {
    _loading = true;
    notifyListeners();

    try {
      final fetched = await _repository.fetchTop();
      // In debug, con pochi utenti reali il podio/la lista risultano vuoti
      // o incompleti: si mostrano dati di esempio per poter verificare il
      // layout. Non viene mai eseguito nelle build di release.
      if (_enableMockFallback && fetched.length < 3) {
        _entries = _mockEntries;
        _reportCounts = _mockReportCounts;
        _loaded = true;
        notifyListeners();
        return;
      }

      _entries = fetched;
      _loaded = true;
      notifyListeners();
      await _loadReportCounts();
    } catch (e) {
      setError(e);
    } finally {
      _loading = false;
      notifyListeners();
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

  static const _mockEntries = [
    LeaderboardEntry(
      rank: 1,
      uid: 'mock_giulia',
      name: 'Giulia R.',
      points: 2860,
    ),
    LeaderboardEntry(rank: 2, uid: 'mock_luca', name: 'Luca B.', points: 2140),
    LeaderboardEntry(
      rank: 3,
      uid: 'mock_martina',
      name: 'Martina C.',
      points: 1730,
    ),
    LeaderboardEntry(
      rank: 4,
      uid: 'mock_alessandro',
      name: 'Alessandro M.',
      points: 1410,
    ),
    LeaderboardEntry(rank: 5, uid: 'mock_sara', name: 'Sara T.', points: 1220),
    LeaderboardEntry(
      rank: 6,
      uid: 'mock_davide',
      name: 'Davide P.',
      points: 940,
    ),
    LeaderboardEntry(rank: 7, uid: 'mock_marco', name: 'Marco B.', points: 785),
    LeaderboardEntry(
      rank: 8,
      uid: 'mock_francesco',
      name: 'Francesco G.',
      points: 620,
    ),
  ];

  static const _mockReportCounts = {
    'mock_giulia': 56,
    'mock_luca': 42,
    'mock_martina': 34,
    'mock_alessandro': 28,
    'mock_sara': 26,
    'mock_davide': 23,
    'mock_marco': 19,
    'mock_francesco': 17,
  };
}
