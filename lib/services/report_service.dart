import '../models/report_draft.dart';
import '../repositories/report_repository.dart';

class ReportService {
  ReportService({ReportRepository? repository})
      : _repository = repository ?? FirestoreReportRepository();

  final ReportRepository _repository;

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
    final draft = ReportDraft(
      note: cleaned,
      photoPath: photoPath,
      latitude: latitude,
      longitude: longitude,
    );
    await _repository.submitReport(draft: draft, uid: uid);
  }
}
