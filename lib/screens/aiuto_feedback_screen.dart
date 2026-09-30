import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

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
          'Ogni segnalazione inviata e ogni pulizia completata contribuiscono al tuo punteggio.',
    ),
    (
      question: 'Posso eliminare una mia segnalazione?',
      answer:
          'Non direttamente dall\'app: eliminando il tuo account, le segnalazioni restano sulla mappa in forma anonima.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aiuto e feedback')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _faqs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final faq = _faqs[i];
          return Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceWarm,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              title: Text(
                faq.question,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              iconColor: AppColors.greenBrand,
              collapsedIconColor: AppColors.textSecondary,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    faq.answer,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
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
