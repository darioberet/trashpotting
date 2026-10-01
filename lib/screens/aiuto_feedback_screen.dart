import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/app_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';

class AiutoFeedbackScreen extends StatelessWidget {
  const AiutoFeedbackScreen({super.key});

  static const _faqs = [
    (
      question: 'Come funziona la verifica di una segnalazione?',
      answer:
          'Ogni nuova segnalazione viene mostrata sulla mappa come "Aperta" dopo un controllo automatico. '
          'La community può confermare che il rifiuto è ancora presente o segnalarne la rimozione.',
    ),
    (
      question: 'Cosa significano gli stati di una segnalazione?',
      answer:
          '"Segnalata" è il primo passo. "Aperta" significa che è visibile e verificata. '
          '"In lavorazione" indica che qualcuno se ne sta occupando o ha organizzato un evento. '
          '"Pulita" significa che il rifiuto è stato rimosso.',
    ),
    (
      question: 'Come guadagno punti in classifica?',
      answer:
          'Ogni segnalazione inviata vale 1 punto, ogni pulizia completata (con la foto finale) vale 2 punti.',
    ),
    (
      question: 'Posso eliminare una mia segnalazione?',
      answer:
          'Non direttamente dall\'app: eliminando il tuo account, le segnalazioni restano sulla mappa in forma anonima.',
    ),
  ];

  static const _feedbackEmail = 'dario.berettini.eco@gmail.com';

  Future<void> _writeToUs(BuildContext context) async {
    final session = AppSessionScope.of(context);
    final info = await PackageInfo.fromPlatform();
    final uri = Uri(
      scheme: 'mailto',
      path: _feedbackEmail,
      // `query` invece di `queryParameters`: quest'ultimo codifica gli spazi
      // come "+", che molte app di posta mostrano letteralmente.
      query: _encodeQuery({
        'subject': 'Feedback Trashpotting',
        'body':
            '\n\n---\nVersione app: ${info.version} (${info.buildNumber})\n'
            'ID utente: ${session.currentUserId ?? '-'}',
      }),
    );
    final opened = await launchUrl(uri);
    if (!opened) {
      session.publishInfo(
        'Nessuna app di posta trovata. Scrivici a $_feedbackEmail',
      );
    }
  }

  static String _encodeQuery(Map<String, String> params) => params.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aiuto e feedback')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton.icon(
          onPressed: () => _writeToUs(context),
          icon: const Icon(Icons.mail_outline),
          label: const Text('Scrivici'),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _faqs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final faq = _faqs[i];
          return Container(
            decoration: BoxDecoration(
              color: context.palette.surfaceWarm,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              title: Text(
                faq.question,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.palette.textPrimary,
                ),
              ),
              iconColor: AppColors.greenBrand,
              collapsedIconColor: context.palette.textSecondary,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    faq.answer,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.palette.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
