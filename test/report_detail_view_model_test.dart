import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trashpotting_v3/models/app_user_profile.dart';
import 'package:trashpotting_v3/repositories/report_repository.dart';
import 'package:trashpotting_v3/repositories/user_profile_repository.dart';
import 'package:trashpotting_v3/services/photo_upload_service.dart';
import 'package:trashpotting_v3/state/report_detail_view_model.dart';

// I fake implementano solo i metodi usati qui; il resto non viene chiamato.
class _FakeReports implements ReportRepository {
  final calls = <String>[];
  Completer<void>? startGate;
  Object? failWith;

  @override
  Future<void> startCleaning({
    required String reportId,
    required AppUserProfile actor,
  }) async {
    calls.add('start');
    await startGate?.future;
    if (failWith != null) throw failWith!;
  }

  @override
  Future<void> completeCleaning({
    required String reportId,
    required AppUserProfile actor,
    required String cleanupPhotoUrl,
  }) async => calls.add('complete:$cleanupPhotoUrl');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePhotos implements PhotoUploadService {
  @override
  Future<String> uploadCleanupPhoto({
    required String localPath,
    required String ownerId,
    required String reportId,
  }) async => 'https://foto/$reportId';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProfiles implements UserProfileRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const user = AppUserProfile(uid: 'u1', username: 'davide');
  late _FakeReports reports;
  late ReportDetailViewModel vm;

  setUp(() {
    reports = _FakeReports();
    vm = ReportDetailViewModel(
      reportId: 'r1',
      repository: reports,
      photoUploadService: _FakePhotos(),
      userProfileRepository: _FakeProfiles(),
    );
  });

  test('completeCleaning carica la foto e chiude la segnalazione', () async {
    final message = await vm.completeCleaning(user, '/tmp/foto.jpg');

    expect(message, 'Report segnato come ripulito.');
    expect(reports.calls, ['complete:https://foto/r1']);
    expect(vm.busy, isFalse);
  });

  test(
    'un secondo tocco mentre un\'azione è in corso viene ignorato',
    () async {
      reports.startGate = Completer<void>();
      final first = vm.startCleaning(user);
      expect(vm.busy, isTrue);

      expect(await vm.joinEvent(user), isNull);

      reports.startGate!.complete();
      expect(await first, 'Pulizia presa in carico.');
      expect(vm.busy, isFalse);
    },
  );

  test('gli errori vengono rilanciati e busy torna falso', () async {
    reports.failWith = StateError('Già presa in carico');

    await expectLater(vm.startCleaning(user), throwsStateError);
    expect(vm.busy, isFalse);
  });
}
