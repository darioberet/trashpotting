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
}
