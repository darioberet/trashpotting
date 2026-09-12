import '../models/report_draft.dart';
import '../repositories/leaderboard_repository.dart';
import '../repositories/report_repository.dart';
import 'photo_upload_service.dart';

class ReportService {
  ReportService({
    ReportRepository? repository,
    PhotoUploadService? photoUploadService,
    LeaderboardRepository? leaderboardRepository,
  })  : _repository = repository ?? FirestoreReportRepository(),
        _photoUploadService = photoUploadService,
        _leaderboardRepository =
            leaderboardRepository ?? FirestoreLeaderboardRepository();

  final ReportRepository _repository;
  final PhotoUploadService? _photoUploadService;
  final LeaderboardRepository _leaderboardRepository;

  Future<void> submit({
    required String note,
    String? uid,
    String? displayName,
    String? photoPath,
    double? latitude,
    double? longitude,
    String? type,
    String? address,
  }) async {
    final cleaned = note.trim();
    if (cleaned.length < 10) {
      throw ArgumentError.value(note, 'note', 'Inserisci almeno 10 caratteri.');
    }

    String? photoUrl;
    if (photoPath != null && photoPath.trim().isNotEmpty) {
      photoUrl = await (_photoUploadService ?? PhotoUploadService())
          .uploadReportPhoto(
        localPath: photoPath,
        ownerId: uid ?? 'guest',
      );
    }

    final draft = ReportDraft(
      note: cleaned,
      photoUrl: photoUrl,
      latitude: latitude,
      longitude: longitude,
      type: type,
      address: address,
    );
    await _repository.submitReport(draft: draft, uid: uid);

    if (uid != null) {
      final name = (displayName?.trim().isNotEmpty == true)
          ? displayName!.trim()
          : 'Utente';
      await _leaderboardRepository.incrementPoints(uid: uid, displayName: name);
    }
  }
}
