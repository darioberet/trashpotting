import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trashpotting_v3/models/app_notification.dart';
import 'package:trashpotting_v3/repositories/notification_repository.dart';
import 'package:trashpotting_v3/repositories/user_profile_repository.dart';
import 'package:trashpotting_v3/screens/notifiche_screen.dart';
import 'package:trashpotting_v3/state/app_session.dart';

class _FakeNotificationRepository implements NotificationRepository {
  _FakeNotificationRepository(this._stream);

  final Stream<List<AppNotification>> _stream;

  @override
  Future<void> markRead({
    required String uid,
    required String notificationId,
  }) async {}

  @override
  Stream<List<AppNotification>> watchUserNotifications(String uid) => _stream;
}

/// Evita che [AppSession] crei un [UserProfileRepository] reale, che
/// richiederebbe Firebase inizializzato.
class _FakeUserProfileRepository implements UserProfileRepository {
  @override
  Future<bool> hasCompletedOnboarding(String uid) async => true;

  @override
  Future<void> setOnboardingComplete(String uid, bool value) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AppSession _testSession() => AppSession(
  firebaseReady: true,
  initialUserId: 'u_test',
  bindAuthStream: false,
  userProfileRepository: _FakeUserProfileRepository(),
);

Widget _buildHost({
  required AppSession session,
  required NotificationRepository repository,
}) {
  return AppSessionScope(
    session: session,
    child: MaterialApp(home: NotificheScreen(repository: repository)),
  );
}

void main() {
  testWidgets('Notifiche shows loading while waiting stream data', (
    tester,
  ) async {
    final controller = StreamController<List<AppNotification>>();
    addTearDown(controller.close);

    final session = _testSession();
    addTearDown(session.dispose);

    await tester.pumpWidget(
      _buildHost(
        session: session,
        repository: _FakeNotificationRepository(controller.stream),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Notifiche shows empty state when stream emits empty list', (
    tester,
  ) async {
    final controller = StreamController<List<AppNotification>>();
    addTearDown(controller.close);

    final session = _testSession();
    addTearDown(session.dispose);

    await tester.pumpWidget(
      _buildHost(
        session: session,
        repository: _FakeNotificationRepository(controller.stream),
      ),
    );

    controller.add(const []);
    await tester.pump();

    expect(find.text('Nessuna notifica'), findsOneWidget);
  });

  testWidgets('Notifiche shows error copy when stream fails', (tester) async {
    final controller = StreamController<List<AppNotification>>();
    addTearDown(controller.close);

    final session = _testSession();
    addTearDown(session.dispose);

    await tester.pumpWidget(
      _buildHost(
        session: session,
        repository: _FakeNotificationRepository(controller.stream),
      ),
    );

    controller.addError(StateError('boom'));
    await tester.pump();

    expect(
      find.textContaining('Impossibile caricare le notifiche'),
      findsOneWidget,
    );
  });
}
