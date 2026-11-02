import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/legal.dart';
import '../state/app_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../widgets/menu_card.dart';
import '../widgets/tab_header.dart';

class AiutoFeedbackScreen extends StatelessWidget {
  const AiutoFeedbackScreen({super.key});

  static const _faqs = [
    (
      question: 'Come funziona la verifica di una segnalazione?',
      answer:
          'Ogni nuova segnalazione compare subito sulla mappa come "Segnalata". '
          'Chi passa vicino può confermare che il rifiuto è ancora lì (diventa '
          '"Aperta") o indicare che non c\'è più.',
    ),
    (
      question: 'Cosa significano gli stati di una segnalazione?',
      answer:
          '"Segnalata": appena inviata. "Aperta": almeno una persona sul posto '
          'ha confermato che il rifiuto c\'è ancora. "In corso": qualcuno se ne '
          'sta occupando o ha organizzato un evento. "Ripulita": rimossa, con la '
          'foto finale. Se più persone indicano che non c\'è più, la '
          'segnalazione sparisce dalla mappa.',
    ),
    (
      question: 'Come guadagno punti in classifica?',
      answer:
          'Segnalazione inviata: 1 punto. Pulizia completata (con la foto finale): 2 punti. '
          'Rispondere a "È ancora lì?" su una segnalazione vicina: 1 punto.',
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BackHeader(title: 'Aiuto e feedback'),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    24 + MediaQuery.of(context).padding.bottom,
                  ),
                  children: [
                    const SectionLabel('Domande frequenti'),
                    for (final faq in _faqs) ...[
                      _FaqCard(question: faq.question, answer: faq.answer),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 14),
                    const SectionLabel('Contatti e documenti'),
                    MenuCard(
                      children: [
                        MenuTile(
                          icon: AppIcons.email,
                          label: 'Scrivici',
                          subtitle: 'Dubbi, problemi o idee: rispondiamo noi.',
                          bg: AppColors.purpleLight,
                          fg: AppColors.purpleDark,
                          onTap: () => _writeToUs(context),
                        ),
                        MenuTile(
                          icon: AppIcons.shield,
                          label: 'Informativa privacy',
                          bg: AppColors.greenLight,
                          fg: AppColors.greenDark,
                          onTap: () => LegalLinks.open(LegalLinks.privacy),
                        ),
                        MenuTile(
                          icon: AppIcons.document,
                          label: 'Termini d\'uso',
                          bg: AppColors.greenLight,
                          fg: AppColors.greenDark,
                          onTap: () => LegalLinks.open(LegalLinks.terms),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const _AppVersion(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Domanda frequente: card bianca che si apre al tocco.
class _FaqCard extends StatelessWidget {
  const _FaqCard({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: AppColors.mintBorder, offset: Offset(0, 2)),
        ],
      ),
      child: Theme(
        // Niente linee sopra e sotto quando la domanda è aperta.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          iconColor: AppColors.greenBrand,
          collapsedIconColor: AppColors.textSecondary,
          title: Text(
            question,
            style: const TextStyle(
              fontSize: 15,
              height: 20 / 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          children: [
            Text(
              answer,
              style: const TextStyle(
                fontSize: 14,
                height: 21 / 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Versione dell'app, utile quando qualcuno ci scrive per un problema.
class _AppVersion extends StatelessWidget {
  const _AppVersion();

  // Una sola lettura: ricrearla a ogni build rifarebbe la richiesta.
  static final _info = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: _info,
      builder: (context, snap) {
        final info = snap.data;
        if (info == null) return const SizedBox.shrink();
        return Text(
          'Trashpotting ${info.version} (${info.buildNumber})',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.textDisabled),
        );
      },
    );
  }
}
