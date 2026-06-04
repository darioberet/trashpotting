import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

String mapAppError(Object error, {String fallback = 'Si e verificato un errore.'}) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'operation-not-allowed':
        return 'Accesso non consentito. Verifica la configurazione Firebase Auth.';
      case 'network-request-failed':
        return 'Problema di rete. Controlla la connessione e riprova.';
      case 'too-many-requests':
        return 'Troppi tentativi. Attendi qualche minuto e riprova.';
      default:
        return 'Errore di autenticazione. Riprova.';
    }
  }

  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return 'Permessi insufficienti per completare l operazione.';
      case 'unavailable':
        return 'Servizio temporaneamente non disponibile. Riprova tra poco.';
      case 'failed-precondition':
        return 'Configurazione incompleta del backend. Controlla indici e regole.';
      default:
        return 'Errore Firebase. Riprova.';
    }
  }

  if (kDebugMode) {
    return '$fallback Dettaglio: $error';
  }
  return fallback;
}
