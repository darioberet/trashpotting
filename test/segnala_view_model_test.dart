import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trashpotting_v3/models/app_user_profile.dart';
import 'package:trashpotting_v3/models/leaderboard_entry.dart';
import 'package:trashpotting_v3/models/report_filter.dart';
import 'package:trashpotting_v3/models/report_draft.dart';
import 'package:trashpotting_v3/models/trashpot_report.dart';
import 'package:trashpotting_v3/repositories/leaderboard_repository.dart';
import 'package:trashpotting_v3/repositories/report_repository.dart';
import 'package:trashpotting_v3/services/report_service.dart';
import 'package:trashpotting_v3/state/segnala_view_model.dart';

class _NoopReportRepository implements ReportRepository {
  @override
  Future<void> completeCleaning({
    required String reportId,
    required AppUserProfile actor,
    required String cleanupPhotoUrl,
  }) async {}

  @override
  Future<void> joinCleanupEvent({
    required String reportId,
    required AppUserProfile participant,
  }) async {}

  @override
  Future<void> scheduleCleanupEvent({
    required String reportId,
    required AppUserProfile creator,
    required DateTime scheduledAt,
  }) async {}

  @override
  Future<void> startCleaning({
    required String reportId,
    required AppUserProfile actor,
  }) async {}

  @override
  Stream<List<TrashpotReport>> watchReports({int limit = 50}) =>
      const Stream<List<TrashpotReport>>.empty();

  @override
  Stream<List<TrashpotReport>> watchReportsNear({
    required double latitude,
    required double longitude,
    required double radiusKm,
    required Set<ReportStatusGroup> statusGroups,
  }) => const Stream<List<TrashpotReport>>.empty();

  @override
  Stream<List<TrashpotReport>> watchReportsByUser(
    String uid, {
    int limit = 50,
  }) => const Stream<List<TrashpotReport>>.empty();

  @override
  Stream<TrashpotReport?> watchReport(String reportId) =>
      const Stream<TrashpotReport?>.empty();

  @override
  Future<void> submitReport({required ReportDraft draft, String? uid}) async {}

  @override
  Future<void> anonymizeUserReports(String uid) async {}

  @override
  Future<List<TrashpotReport>> findActiveNearby({
    required double latitude,
    required double longitude,
    double radiusMeters = duplicateRadiusMeters,
  }) async => const [];

  @override
  Future<int> remainingReportsToday(String uid) async => maxReportsPerDay;

  @override
  Future<int> countByUser(String uid) async => 0;
}

typedef _SubmitHandler =
    Future<void> Function({
      required String note,
      String? uid,
      String? username,
      String? photoPath,
      double? latitude,
      double? longitude,
      String? type,
      String? address,
    });

class _NoopLeaderboardRepository implements LeaderboardRepository {
  @override
  Future<List<LeaderboardEntry>> fetchTop({int limit = 20}) async => const [];

  @override
  Future<void> incrementPoints({
    required String uid,
    required String username,
    int amount = pointsPerReport,
  }) async {}

  @override
  Future<int> fetchUserPoints(String uid) async => 0;

  @override
  Future<void> updateUsername({
    required String uid,
    required String username,
  }) async {}

  @override
  Future<void> deleteEntry(String uid) async {}
}

class _FakeReportService extends ReportService {
  _FakeReportService(this._handler)
    : super(
        repository: _NoopReportRepository(),
        leaderboardRepository: _NoopLeaderboardRepository(),
      );

  final _SubmitHandler _handler;
  int calls = 0;
  String? lastNote;
  String? lastUid;
  String? lastPhotoPath;
  double? lastLatitude;
  double? lastLongitude;

  @override
  Future<void> submit({
    required String note,
    String? uid,
    String? username,
    String? photoPath,
    double? latitude,
    double? longitude,
    String? type,
    String? address,
  }) async {
    calls += 1;
    lastNote = note;
    lastUid = uid;
    lastPhotoPath = photoPath;
    lastLatitude = latitude;
    lastLongitude = longitude;
    await _handler(
      note: note,
      uid: uid,
      username: username,
      photoPath: photoPath,
      latitude: latitude,
      longitude: longitude,
      type: type,
      address: address,
    );
  }
}

void main() {
  test('submit publishes info when firebase is not ready', () async {
    final service = _FakeReportService(
      ({
        required note,
        uid,
        username,
        photoPath,
        latitude,
        longitude,
        type,
        address,
      }) async {},
    );
    final vm = SegnalaViewModel(reportService: service);

    await vm.submit(firebaseReady: false, note: 'qualsiasi testo', uid: 'u1');

    expect(service.calls, 0);
    expect(vm.sending, isFalse);
    expect(vm.infoToken, 1);
    expect(vm.lastInfo, contains('Backend non disponibile'));
    expect(vm.errorToken, 0);
  });

  test('submit success toggles sending and stores success info', () async {
    final service = _FakeReportService(
      ({
        required note,
        uid,
        username,
        photoPath,
        latitude,
        longitude,
        type,
        address,
      }) async {},
    );
    final vm = SegnalaViewModel(reportService: service);

    vm.setPhotoPath('/tmp/photo.jpg');
    vm.setLocation(latitude: 43.6158, longitude: 13.5189);

    await vm.submit(
      firebaseReady: true,
      note: 'segnalazione valida',
      uid: 'u1',
    );

    expect(service.calls, 1);
    expect(service.lastNote, 'segnalazione valida');
    expect(service.lastUid, 'u1');
    expect(service.lastPhotoPath, '/tmp/photo.jpg');
    expect(service.lastLatitude, 43.6158);
    expect(service.lastLongitude, 13.5189);
    expect(vm.sending, isFalse);
    expect(vm.infoToken, 1);
    expect(vm.lastInfo, 'Segnalazione inviata correttamente.');
    expect(vm.errorToken, 0);
  });

  test('submit failure stores error token and error object', () async {
    final error = StateError('send failed');
    final service = _FakeReportService(({
      required note,
      uid,
      username,
      photoPath,
      latitude,
      longitude,
      type,
      address,
    }) async {
      throw error;
    });
    final vm = SegnalaViewModel(reportService: service);

    await vm.submit(
      firebaseReady: true,
      note: 'segnalazione valida',
      uid: 'u1',
    );

    expect(service.calls, 1);
    expect(vm.sending, isFalse);
    expect(vm.errorToken, 1);
    expect(vm.lastError, error);
    expect(vm.lastErrorFallback, contains('Invio segnalazione'));
  });

  test('submit ignores concurrent call while sending', () async {
    final completer = Completer<void>();
    final service = _FakeReportService(({
      required note,
      uid,
      username,
      photoPath,
      latitude,
      longitude,
      type,
      address,
    }) async {
      await completer.future;
    });
    final vm = SegnalaViewModel(reportService: service);

    final first = vm.submit(
      firebaseReady: true,
      note: 'segnalazione valida',
      uid: 'u1',
    );
    final second = vm.submit(
      firebaseReady: true,
      note: 'seconda chiamata',
      uid: 'u2',
    );

    await Future<void>.delayed(Duration.zero);
    expect(service.calls, 1);

    completer.complete();
    await first;
    await second;

    expect(vm.sending, isFalse);
    expect(vm.infoToken, 1);
  });
}
