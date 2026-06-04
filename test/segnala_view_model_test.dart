import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trashpotting_v3/repositories/report_repository.dart';
import 'package:trashpotting_v3/services/report_service.dart';
import 'package:trashpotting_v3/state/segnala_view_model.dart';

class _NoopReportRepository implements ReportRepository {
  @override
  Future<void> submitReport({required draft, String? uid}) async {}
}

typedef _SubmitHandler = Future<void> Function({required String note, String? uid});

class _FakeReportService extends ReportService {
  _FakeReportService(this._handler) : super(repository: _NoopReportRepository());

  final _SubmitHandler _handler;
  int calls = 0;
  String? lastNote;
  String? lastUid;

  @override
  Future<void> submit({required String note, String? uid}) async {
    calls += 1;
    lastNote = note;
    lastUid = uid;
    await _handler(note: note, uid: uid);
  }
}

void main() {
  test('submit publishes info when firebase is not ready', () async {
    final service = _FakeReportService(({required note, uid}) async {});
    final vm = SegnalaViewModel(reportService: service);

    await vm.submit(firebaseReady: false, note: 'qualsiasi testo', uid: 'u1');

    expect(service.calls, 0);
    expect(vm.sending, isFalse);
    expect(vm.infoToken, 1);
    expect(vm.lastInfo, contains('Backend non disponibile'));
    expect(vm.errorToken, 0);
  });

  test('submit success toggles sending and stores success info', () async {
    final service = _FakeReportService(({required note, uid}) async {});
    final vm = SegnalaViewModel(reportService: service);

    await vm.submit(firebaseReady: true, note: 'segnalazione valida', uid: 'u1');

    expect(service.calls, 1);
    expect(service.lastNote, 'segnalazione valida');
    expect(service.lastUid, 'u1');
    expect(vm.sending, isFalse);
    expect(vm.infoToken, 1);
    expect(vm.lastInfo, 'Segnalazione inviata correttamente.');
    expect(vm.errorToken, 0);
  });

  test('submit failure stores error token and error object', () async {
    final error = StateError('send failed');
    final service = _FakeReportService(({required note, uid}) async {
      throw error;
    });
    final vm = SegnalaViewModel(reportService: service);

    await vm.submit(firebaseReady: true, note: 'segnalazione valida', uid: 'u1');

    expect(service.calls, 1);
    expect(vm.sending, isFalse);
    expect(vm.errorToken, 1);
    expect(vm.lastError, error);
    expect(vm.lastErrorFallback, contains('Invio segnalazione'));
  });

  test('submit ignores concurrent call while sending', () async {
    final completer = Completer<void>();
    final service = _FakeReportService(({required note, uid}) async {
      await completer.future;
    });
    final vm = SegnalaViewModel(reportService: service);

    final first = vm.submit(firebaseReady: true, note: 'segnalazione valida', uid: 'u1');
    final second = vm.submit(firebaseReady: true, note: 'seconda chiamata', uid: 'u2');

    await Future<void>.delayed(Duration.zero);
    expect(service.calls, 1);

    completer.complete();
    await first;
    await second;

    expect(vm.sending, isFalse);
    expect(vm.infoToken, 1);
  });
}
