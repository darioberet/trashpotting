import 'package:url_launcher/url_launcher.dart';

/// Pagine legali pubblicate su Firebase Hosting (cartella `hosting/`).
/// Gli stessi link vanno nella scheda dello store (Google Play).
abstract final class LegalLinks {
  static const _base = 'https://trashpotting-app.web.app';
  static final privacy = Uri.parse('$_base/privacy');
  static final terms = Uri.parse('$_base/termini');
  static final accountDeletion = Uri.parse('$_base/eliminazione-account');

  /// Versione di privacy e termini accettata in registrazione: va aumentata
  /// quando i testi cambiano in modo rilevante.
  static const version = 1;

  static Future<bool> open(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.inAppBrowserView);
}
