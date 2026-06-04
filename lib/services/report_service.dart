import '../models/report_draft.dart';
import '../repositories/report_repository.dart';
import 'photo_upload_service.dart';

class ReportService {
  ReportService({
    ReportRepository? repository,
    PhotoUploadService? photoUploadService,
  })  : _repository = repository ?? FirestoreReportRepository(),
        _photoUploadService = photoUploadService;

  final ReportRepository _repository;
  final PhotoUploadService? _photoUploadService;

  Future<void> submit({
    required String note,
    String? uid,
    String? photoPath,
    double? latitude,
    double? longitude,
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
    );
    await _repository.submitReport(draft: draft, uid: uid);
  }
}
