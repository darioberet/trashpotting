import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import 'app_button.dart';
import 'illustration.dart';

/// Schermata mostrata sopra l'app a un utente bloccato da un admin. Le
/// regole Firestore impediscono comunque le scritture: questa schermata
/// spiega perché, invece di lasciare errori di permesso a ogni azione.
class BlockedGate extends StatelessWidget {
  const BlockedGate({
    super.key,
    required this.blocked,
    required this.onSignOut,
    required this.child,
  });

  final bool blocked;
  final Future<void> Function() onSignOut;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!blocked) return child;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: Material(
            color: AppColors.bgAlt,
            child: IllustratedMessage(
              illustration: const Center(
                child: Icon(AppIcons.block, size: 96, color: AppColors.redPin),
              ),
              badge: (
                icon: AppIcons.shield,
                label: 'Account sospeso',
                bg: AppColors.redLight,
                fg: AppColors.redText,
              ),
              title: 'Il tuo account è sospeso',
              message:
                  'Un moderatore ha sospeso il tuo account per violazione '
                  'delle regole della community. Non puoi pubblicare '
                  'segnalazioni né partecipare alle pulizie.',
              note: const IllustratedNote(
                icon: AppIcons.email,
                boldLead: 'Pensi che sia un errore?',
                text: 'Scrivici a dario.berettini.eco@gmail.com',
                bg: AppColors.purpleLight,
                fg: AppColors.purpleDark,
              ),
              primary: AppButton(
                label: "Esci dall'account",
                icon: AppIcons.logout,
                variant: AppButtonVariant.secondary,
                onPressed: onSignOut,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
