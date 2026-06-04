import '../models/report_draft.dart';
import '../repositories/report_repository.dart';

class ReportService {
  ReportService({ReportRepository? repository})
      : _repository = repository ?? FirestoreReportRepository();

  final ReportRepository _repository;

  Future<void> submit({required String note, String? uid}) async {
    final cleaned = note.trim();
    if (cleaned.length < 10) {
      throw ArgumentError.value(note, 'note', 'Inserisci almeno 10 caratteri.');
    }
    final draft = ReportDraft(note: cleaned);
    await _repository.submitReport(draft: draft, uid: uid);
  }
}
