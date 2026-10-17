import 'package:flutter/foundation.dart';

import '../models/app_user_profile.dart';
import '../repositories/leaderboard_repository.dart';
import '../repositories/report_repository.dart';
import '../repositories/user_profile_repository.dart';
import '../services/photo_upload_service.dart';

/// Stato e azioni del dettaglio di una segnalazione. La schermata si occupa
/// solo di dialog, selettori e messaggi: ogni azione restituisce il testo da
/// mostrare in caso di successo, oppure null se ignorata perché un'altra è
/// già in corso; gli errori vengono rilanciati.
class ReportDetailViewModel extends ChangeNotifier {
  ReportDetailViewModel({
    required this.reportId,
    required ReportRepository repository,
    required LeaderboardRepository leaderboardRepository,
    required PhotoUploadService photoUploadService,
    UserProfileRepository? userProfileRepository,
  }) : _repository = repository,
       _leaderboardRepository = leaderboardRepository,
       _photoUploadService = photoUploadService,
       _userProfileRepository =
           userProfileRepository ?? UserProfileRepository();

  final String reportId;
  final ReportRepository _repository;
  final LeaderboardRepository _leaderboardRepository;
  final PhotoUploadService _photoUploadService;
  final UserProfileRepository _userProfileRepository;

  bool _busy = false;
  bool _voting = false;
  CommunityVote? _myVote;
  bool _voteLoaded = false;
  String? _reporterLabel;
  String? _loadedReporterForUid;
  bool _disposed = false;

  /// Un'azione (presa in carico, evento, pulizia) è in corso.
  bool get busy => _busy;
  bool get voting => _voting;
  CommunityVote? get myVote => _myVote;

  /// Nome di chi ha segnalato, se il profilo è stato caricato.
  String? get reporterLabel => _reporterLabel;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Carica una volta sola il voto già dato da [uid].
  void loadMyVote(String? uid) {
    if (uid == null || _voteLoaded) return;
    _voteLoaded = true;
    _repository
        .myVote(reportId: reportId, uid: uid)
        .then((v) {
          _myVote = v;
          _notify();
        })
        .catchError((_) {});
  }

  void loadReporter(String? uid) {
    if (uid == null || _loadedReporterForUid == uid) return;
    _loadedReporterForUid = uid;
    _userProfileRepository
        .fetchProfile(uid)
        .then((profile) {
          _reporterLabel = profile?.label;
          _notify();
        })
        .catchError((_) {});
  }

  Future<String?> vote({
    required CommunityVote vote,
    required AppUserProfile voter,
    required double latitude,
    required double longitude,
  }) async {
    if (_voting) return null;
    _voting = true;
    _notify();
    try {
      await _repository.vote(
        reportId: reportId,
        voter: voter,
        vote: vote,
        latitude: latitude,
        longitude: longitude,
      );
      _myVote = vote;
      return vote == CommunityVote.present
          ? 'Grazie! Hai confermato la segnalazione (+$pointsPerVote punto).'
          : 'Grazie per l\'aggiornamento (+$pointsPerVote punto).';
    } finally {
      _voting = false;
      _notify();
    }
  }

  Future<String?> startCleaning(AppUserProfile actor) => _run(() async {
    await _repository.startCleaning(reportId: reportId, actor: actor);
    return 'Pulizia presa in carico.';
  });

  Future<String?> joinEvent(AppUserProfile participant) => _run(() async {
    await _repository.joinCleanupEvent(
      reportId: reportId,
      participant: participant,
    );
    return 'Partecipazione confermata.';
  });

  Future<String?> scheduleEvent(AppUserProfile creator, DateTime scheduledAt) =>
      _run(() async {
        await _repository.scheduleCleanupEvent(
          reportId: reportId,
          creator: creator,
          scheduledAt: scheduledAt,
        );
        return 'Evento creato.';
      });

  /// Carica la foto finale, segna la segnalazione come ripulita e assegna i
  /// punti. Un errore sui punti non fa fallire la pulizia, già registrata.
  Future<String?> completeCleaning(AppUserProfile actor, String photoPath) =>
      _run(() async {
        final photoUrl = await _photoUploadService.uploadCleanupPhoto(
          localPath: photoPath,
          ownerId: actor.uid,
          reportId: reportId,
        );
        await _repository.completeCleaning(
          reportId: reportId,
          actor: actor,
          cleanupPhotoUrl: photoUrl,
        );
        try {
          await _leaderboardRepository.incrementPoints(
            uid: actor.uid,
            username: actor.label,
            amount: pointsPerCleanup,
          );
        } catch (e) {
          debugPrint('incrementPoints dopo pulizia non riuscito: $e');
        }
        return 'Report segnato come ripulito.';
      });

  Future<String?> _run(Future<String> Function() action) async {
    if (_busy) return null;
    _busy = true;
    _notify();
    try {
      return await action();
    } finally {
      _busy = false;
      _notify();
    }
  }
}
