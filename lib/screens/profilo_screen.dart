import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../routes.dart';

class ProfiloScreen extends StatelessWidget {
  const ProfiloScreen({
    super.key,
    required this.firebaseReady,
    this.firebaseError,
  });

  final bool firebaseReady;
  final Object? firebaseError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final user = firebaseReady ? FirebaseAuth.instance.currentUser : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const SizedBox(height: 8),
        CircleAvatar(
          radius: 40,
          backgroundColor: cs.primaryContainer,
          foregroundColor: cs.onPrimaryContainer,
          child: Icon(
            user != null ? Icons.person : Icons.person_outline,
            size: 40,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          user != null ? 'Utente' : 'Ospite',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (user != null) ...[
          const SizedBox(height: 4),
          SelectableText(
            user.uid,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ] else ...[
          const SizedBox(height: 8),
          Text(
            firebaseReady
                ? 'Accedi per salvare segnalazioni e notifiche.'
                : 'Firebase non attivo: vedi strumenti debug.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 32),
        ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: const Text('Notifiche'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).pushNamed<void>(AppRoutes.notifiche);
          },
        ),
        ListTile(
          leading: const Icon(Icons.tune_outlined),
          title: const Text('Debug Firebase'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).pushNamed<void>(AppRoutes.debugFirebase);
          },
        ),
      ],
    );
  }
}
