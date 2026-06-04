import 'package:flutter_test/flutter_test.dart';
import 'package:trashpotting_v3/models/leaderboard_entry.dart';
import 'package:trashpotting_v3/repositories/leaderboard_repository.dart';
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
    if (error != null) {
      throw error!;
    }
    return result;
  }
}

void main() {
  test('load uses repository entries on success', () async {
    final repo = _FakeLeaderboardRepository(
      result: const [
        LeaderboardEntry(rank: 1, name: 'A', points: 99),
      ],
    );
    final vm = ClassificaViewModel(repository: repo);

    await vm.load();

    expect(repo.calls, 1);
    expect(vm.loading, isFalse);
    expect(vm.entries, hasLength(1));
    expect(vm.entries.first.name, 'A');
    expect(vm.errorToken, 0);
    expect(vm.lastError, isNull);
  });

  test('load falls back when repository returns empty', () async {
    final repo = _FakeLeaderboardRepository(result: const []);
    final vm = ClassificaViewModel(repository: repo);

    await vm.load();

    expect(vm.loading, isFalse);
    expect(vm.entries, ClassificaViewModel.fallbackEntries);
    expect(vm.errorToken, 0);
    expect(vm.lastError, isNull);
  });

  test('load stores error and fallback entries on failure', () async {
    final error = StateError('boom');
    final repo = _FakeLeaderboardRepository(error: error);
    final vm = ClassificaViewModel(repository: repo);

    await vm.load();

    expect(vm.loading, isFalse);
    expect(vm.entries, ClassificaViewModel.fallbackEntries);
    expect(vm.errorToken, 1);
    expect(vm.lastError, error);
    expect(vm.lastErrorFallback, contains('Classifica non disponibile'));
  });

  test('load notifies listeners at start and end', () async {
    final repo = _FakeLeaderboardRepository(
      result: const [LeaderboardEntry(rank: 1, name: 'A', points: 1)],
    );
    final vm = ClassificaViewModel(repository: repo);
    var notifications = 0;
    vm.addListener(() {
      notifications += 1;
    });

    await vm.load();

    expect(notifications, greaterThanOrEqualTo(2));
  });
}
