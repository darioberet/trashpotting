import 'package:flutter_test/flutter_test.dart';
import 'package:trashpotting_v3/models/report_filter.dart';
import 'package:trashpotting_v3/models/trashpot_report.dart';

void main() {
  test('ogni stato ha al massimo una fase, coerente con i filtri', () {
    for (final s in TrashpotStatus.values) {
      final phases = [s.isToClean, s.isInProgress, s.isCleaned];
      expect(phases.where((p) => p).length, lessThanOrEqualTo(1), reason: '$s');

      final group = ReportStatusGroup.of(s);
      expect(s.isToClean, group == ReportStatusGroup.daPulire, reason: '$s');
      expect(s.isInProgress, group == ReportStatusGroup.inCorso, reason: '$s');
      expect(s.isCleaned, group == ReportStatusGroup.pulite, reason: '$s');
    }
  });

  test('i valori Firestore dei filtri tornano allo stesso gruppo', () {
    for (final group in ReportStatusGroup.values) {
      for (final raw in group.firestoreStatuses) {
        expect(
          ReportStatusGroup.of(trashpotStatusFromString(raw)),
          group,
          reason: raw,
        );
      }
    }
  });
}
