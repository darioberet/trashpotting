import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

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
    final theme = Theme.of(context);
    final palette = context.palette;
    final cs = theme.colorScheme;

    return Stack(
      children: [
        child,
        Positioned.fill(
          child: Material(
            color: theme.scaffoldBackgroundColor,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Spacer(),
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.block, size: 44, color: cs.error),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Account sospeso',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Il tuo account è stato sospeso da un moderatore per '
                      'violazione delle regole della community. Non puoi '
                      'pubblicare segnalazioni né partecipare alle pulizie.\n\n'
                      'Se pensi che sia un errore, scrivici a '
                      'dario.berettini.eco@gmail.com.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onSignOut,
                        child: const Text('Esci dall\'account'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
