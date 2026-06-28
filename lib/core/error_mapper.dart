import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

String mapAppError(
  Object error, {
  String fallback = 'Si e verificato un errore.',
}) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'user-not-found':
      case 'invalid-credential':
        return 'Email o password non corretti.';
      case 'wrong-password':
        return 'Password errata.';
      case 'email-already-in-use':
        return 'Email già in uso. Prova ad accedere.';
      case 'invalid-email':
        return 'Formato email non valido.';
      case 'weak-password':
        return 'Password troppo debole. Usa almeno 6 caratteri.';
      case 'user-disabled':
        return 'Account disabilitato. Contatta il supporto.';
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
    if (error.plugin == 'firebase_storage') {
      switch (error.code) {
        case 'object-not-found':
          return 'Upload foto non riuscito: Firebase Storage non trova la destinazione. Verifica che il bucket esista e sia attivo nel progetto Firebase.';
        case 'unauthenticated':
          return 'Upload foto non autorizzato: App Check o autenticazione Firebase non sono configurati correttamente.';
        case 'unauthorized':
        case 'permission-denied':
          return 'Permessi insufficienti per caricare la foto. Controlla le regole di Firebase Storage.';
        case 'retry-limit-exceeded':
          return 'Upload foto interrotto dalla rete o dal server. Riprova.';
        default:
          return 'Errore Firebase Storage. Riprova.';
      }
    }

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
