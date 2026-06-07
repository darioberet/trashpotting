import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../routes.dart';
import '../services/auth_service.dart';
import '../state/app_session.dart';

class ProfiloScreen extends StatelessWidget {
  const ProfiloScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final session = AppSessionScope.watch(context);
    final firebaseReady = session.firebaseReady;
    final userId = session.currentUserId;
    final user = session.currentUser;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const SizedBox(height: 8),
        CircleAvatar(
          radius: 40,
          backgroundColor: cs.primaryContainer,
          foregroundColor: cs.onPrimaryContainer,
          child: Icon(
            userId != null ? Icons.person : Icons.person_outline,
            size: 40,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          userId != null ? 'Utente' : 'Ospite',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (user != null) ...[
          const SizedBox(height: 4),
          SelectableText(
            user.displayName ?? user.email ?? user.uid,
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
            context.push(AppRoutes.notifiche);
          },
        ),
        ListTile(
          leading: const Icon(Icons.tune_outlined),
          title: const Text('Debug Firebase'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            context.push(AppRoutes.debugFirebase);
          },
        ),
        if (firebaseReady && userId != null)
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              try {
                await AuthService().signOut();
                if (!context.mounted) return;
                AppSessionScope.of(context).publishInfo('Logout effettuato.');
              } catch (e) {
                if (!context.mounted) return;
                AppSessionScope.of(context).publishError(
                  e,
                  fallback: 'Logout non riuscito.',
                );
              }
            },
          ),
      ],
    );
  }
}
