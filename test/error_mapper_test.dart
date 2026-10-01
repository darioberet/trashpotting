import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trashpotting_v3/core/error_mapper.dart';

void main() {
  test('mapAppError maps auth network failures', () {
    final error = FirebaseAuthException(code: 'network-request-failed');
    final message = mapAppError(error);

    expect(message, contains('Problema di rete'));
  });

  test('mapAppError falls back on unknown errors', () {
    final message = mapAppError(Exception('boom'), fallback: 'Fallback');

    expect(message, contains('Fallback'));
  });

  test('mapAppError shows validation messages instead of the raw error', () {
    final error = ArgumentError.value('', 'note', 'Inserisci almeno 10 caratteri.');

    expect(mapAppError(error), 'Inserisci almeno 10 caratteri.');
  });

  test('mapAppError explains timeouts', () {
    final message = mapAppError(
      TimeoutException('gps'),
      fallback: 'Posizione non disponibile.',
    );

    expect(message, startsWith('Posizione non disponibile.'));
    expect(message, isNot(contains('TimeoutException')));
  });

  test('mapAppError explains storage destination errors', () {
    final error = FirebaseException(
      plugin: 'firebase_storage',
      code: 'object-not-found',
      message: 'Object does not exist at location.',
    );

    final message = mapAppError(error);

    expect(message, contains('bucket'));
  });
}
