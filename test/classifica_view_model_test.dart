import 'package:flutter_test/flutter_test.dart';
import 'package:trashpotting_v3/models/app_user_profile.dart';
import 'package:trashpotting_v3/models/leaderboard_entry.dart';
import 'package:trashpotting_v3/models/report_filter.dart';
import 'package:trashpotting_v3/models/report_draft.dart';
import 'package:trashpotting_v3/models/trashpot_report.dart';
import 'package:trashpotting_v3/repositories/leaderboard_repository.dart';
import 'package:trashpotting_v3/repositories/report_repository.dart';
import 'package:trashpotting_v3/state/classifica_view_model.dart';

class _FakeLeaderboardRepository implements LeaderboardRepository {
  _FakeLeaderboardRepository({
    this.result = const <LeaderboardEntry>[],
    this.error,
  });

  final List<LeaderboardEntry> result;
  final Object? error;
  int calls = 0;

  @override
  Future<List<LeaderboardEntry>> fetchTop({int limit = 20}) async {
    calls += 1;
    if (error != null) throw error!;
    return result;
  }

  @override
  Future<void> incrementPoints({
    required String uid,
    required String username,
    int amount = pointsPerReport,
  }) async {}

  @override
  Future<int> fetchUserPoints(String uid) async => 0;

  @override
  Future<int> fetchRankForPoints(int points) async => 1;

  @override
  Future<void> updateUsername({
    required String uid,
    required String username,
  }) async {}

  @override
  Future<void> deleteEntry(String uid) async {}
}

class _FakeReportRepository implements ReportRepository {
  _FakeReportRepository({this.countsByUid = const {}});

  final Map<String, int> countsByUid;

  @override
  Future<List<TrashpotReport>> findActiveNearby({
    required double latitude,
    required double longitude,
    double radiusMeters = duplicateRadiusMeters,
  }) async => const [];

  @override
  Future<CommunityVote?> myVote({
    required String reportId,
    required String uid,
  }) async => null;

  @override
  Future<void> vote({
    required String reportId,
    required AppUserProfile voter,
    required CommunityVote vote,
    required double latitude,
    required double longitude,
  }) async {}

  @override
  Future<int> remainingReportsToday(String uid) async => maxReportsPerDay;

  @override
  Future<int> countByUser(String uid) async => countsByUid[uid] ?? 0;

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
}

void main() {
  test('load uses repository entries on success', () async {
    final repo = _FakeLeaderboardRepository(
      result: const [
        LeaderboardEntry(rank: 1, uid: 'u1', name: 'A', points: 99),
      ],
    );
    final vm = ClassificaViewModel(
      repository: repo,
      reportRepository: _FakeReportRepository(),
    );

    await vm.load();

    expect(repo.calls, 1);
    expect(vm.loading, isFalse);
    expect(vm.entries, hasLength(1));
    expect(vm.entries.first.name, 'A');
    expect(vm.errorToken, 0);
    expect(vm.lastError, isNull);
  });

  test('load returns empty list when repository returns empty', () async {
    final repo = _FakeLeaderboardRepository(result: const []);
    final vm = ClassificaViewModel(
      repository: repo,
      reportRepository: _FakeReportRepository(),
    );

    await vm.load();

    expect(vm.loading, isFalse);
    expect(vm.entries, isEmpty);
    expect(vm.loaded, isTrue);
    expect(vm.errorToken, 0);
    expect(vm.lastError, isNull);
  });

  test('load stores error on failure', () async {
    final error = StateError('boom');
    final repo = _FakeLeaderboardRepository(error: error);
    final vm = ClassificaViewModel(
      repository: repo,
      reportRepository: _FakeReportRepository(),
    );

    await vm.load();

    expect(vm.loading, isFalse);
    expect(vm.errorToken, 1);
    expect(vm.lastError, error);
    expect(vm.lastErrorFallback, contains('Classifica non disponibile'));
  });

  test('load notifies listeners at start and end', () async {
    final repo = _FakeLeaderboardRepository(
      result: const [
        LeaderboardEntry(rank: 1, uid: 'u1', name: 'A', points: 1),
      ],
    );
    final vm = ClassificaViewModel(
      repository: repo,
      reportRepository: _FakeReportRepository(),
    );
    var notifications = 0;
    vm.addListener(() => notifications += 1);

    await vm.load();

    expect(notifications, greaterThanOrEqualTo(2));
  });

  test('load fetches report counts per uid from ReportRepository', () async {
    final repo = _FakeLeaderboardRepository(
      result: const [
        LeaderboardEntry(rank: 1, uid: 'u1', name: 'A', points: 10),
        LeaderboardEntry(rank: 2, uid: 'u2', name: 'B', points: 5),
      ],
    );
    final reportRepo = _FakeReportRepository(countsByUid: {'u1': 12, 'u2': 3});
    final vm = ClassificaViewModel(
      repository: repo,
      reportRepository: reportRepo,
    );

    await vm.load();

    expect(vm.reportCountFor('u1'), 12);
    expect(vm.reportCountFor('u2'), 3);
    expect(vm.reportCountFor('unknown'), isNull);
  });

  test('load shows real entries even when fewer than 3', () async {
    final repo = _FakeLeaderboardRepository(
      result: const [
        LeaderboardEntry(rank: 1, uid: 'u1', name: 'A', points: 1),
      ],
    );
    final vm = ClassificaViewModel(
      repository: repo,
      reportRepository: _FakeReportRepository(),
    );

    await vm.load();

    expect(vm.entries, hasLength(1));
    expect(vm.entries.first.uid, 'u1');
  });
}
