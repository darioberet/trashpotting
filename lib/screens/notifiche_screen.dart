import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../repositories/notification_repository.dart';
import '../state/app_session.dart';

/// Schermata Notifiche — allineata al percorso `/app/notifiche` del prototipo Figma Make.
/// Dati: sottocollezione `users/{uid}/notifications` (documenti con title, body, read, createdAt).
class NotificheScreen extends StatelessWidget {
  NotificheScreen({super.key, NotificationRepository? repository})
  : _repository = repository ?? FirestoreNotificationRepository();

  final NotificationRepository _repository;

  static const mockItems = <_MockNotification>[
    _MockNotification(
      title: 'Nuovo segnalazione vicino a te',
      body: 'È stata aperta una segnalazione nel raggio di 500 m. Tocca per i dettagli.',
      timeLabel: '10 min',
      read: false,
      icon: Icons.place_outlined,
    ),
    _MockNotification(
      title: 'Raccolta confermata',
      body: 'Il punto segnalato in Via Roma è stato verificato dalla community.',
      timeLabel: 'Ieri',
      read: true,
      icon: Icons.check_circle_outline,
    ),
    _MockNotification(
      title: 'Promemoria',
      body: 'Completa il profilo per ricevere avvisi personalizzati.',
      timeLabel: '3 giorni fa',
      read: true,
      icon: Icons.person_outline,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final session = AppSessionScope.watch(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final firebaseReady = session.firebaseReady;
    final firebaseError = session.firebaseError;
    final currentUserId = session.currentUserId;

    final appBar = SliverAppBar.large(
      title: const Text('Notifiche'),
      backgroundColor: cs.surface,
    );

    // StreamBuilder must not appear as a direct child of a sliver slot (e.g.
    // SliverPadding.sliver): only widgets that mount RenderSliver are valid there.
    if (firebaseReady && currentUserId != null) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: StreamBuilder<List<AppNotification>>(
          stream: _repository.watchUserNotifications(currentUserId),
          builder: (context, snap) {
            return CustomScrollView(
              slivers: [
                appBar,
                ..._cloudNotificationSlivers(
                  context,
                  _repository,
                  theme,
                  cs,
                  currentUserId,
                  snap,
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            );
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          appBar,
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: _InfoBanner(
                firebaseReady: firebaseReady,
                firebaseError: firebaseError,
                signedIn: currentUserId != null,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final m = mockItems[i];
                  return _NotificationCard(
                    title: m.title,
                    body: m.body,
                    timeLabel: m.timeLabel,
                    read: m.read,
                    icon: m.icon,
                    onTap: () {},
                  );
                },
                childCount: mockItems.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  /// Returns only sliver widgets (each subtree mounts a [RenderSliver]).
  static List<Widget> _cloudNotificationSlivers(
    BuildContext context,
    NotificationRepository repository,
    ThemeData theme,
    ColorScheme cs,
    String uid,
    AsyncSnapshot<List<AppNotification>> snap,
  ) {
    if (snap.hasError) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Impossibile caricare le notifiche.\n'
              '${snap.error}\n\n'
              'Controlla le regole Firestore per '
              '`users/{uid}/notifications`.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.error,
              ),
            ),
          ),
        ),
      ];
    }
    if (!snap.hasData) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ];
    }
    final notifications = snap.data!;
    if (notifications.isEmpty) {
      return [SliverToBoxAdapter(child: _EmptyState(theme: theme, cs: cs))];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final n = notifications[i];
              return _NotificationCard(
                title: n.title,
                body: n.body,
                timeLabel: _formatRelative(n.createdAt),
                read: n.read,
                icon: _iconForType(n.type),
                onTap: () => _markRead(context, repository, uid, n),
              );
            },
            childCount: notifications.length,
          ),
        ),
      ),
    ];
  }

  static IconData _iconForType(String? type) {
    switch (type) {
      case 'report':
        return Icons.report_outlined;
      case 'success':
        return Icons.check_circle_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  static String _formatRelative(DateTime? at) {
    if (at == null) return '';
    final now = DateTime.now();
    final d = now.difference(at);
    if (d.inMinutes < 1) return 'Adesso';
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    if (d.inHours < 24) return '${d.inHours} h';
    if (d.inDays < 7) return '${d.inDays} gg';
    return '${at.day}/${at.month}/${at.year}';
  }

  static Future<void> _markRead(
    BuildContext context,
    NotificationRepository repository,
    String uid,
    AppNotification n,
  ) async {
    if (n.read) return;
    final session = AppSessionScope.of(context);
    try {
      await repository.markRead(uid: uid, notificationId: n.id);
    } catch (e) {
      if (!context.mounted) return;
      session.publishError(
        e,
        fallback: 'Impossibile aggiornare la notifica.',
      );
    }
  }
}

class _MockNotification {
  const _MockNotification({
    required this.title,
    required this.body,
    required this.timeLabel,
    required this.read,
    required this.icon,
  });

  final String title;
  final String body;
  final String timeLabel;
  final bool read;
  final IconData icon;
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.firebaseReady,
    required this.signedIn,
    this.firebaseError,
  });

  final bool firebaseReady;
  final bool signedIn;
  final Object? firebaseError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    String msg;
    if (!firebaseReady) {
      msg =
          'Firebase non inizializzato. Controlla `flutterfire configure` e riavvia l’app.\n$firebaseError';
    } else if (!signedIn) {
      msg =
          'Accedi per vedere le notifiche dal cloud. Intanto vedi dati di esempio.';
    } else {
      msg = '';
    }
    if (msg.isEmpty) return const SizedBox.shrink();
    return Material(
      color: cs.secondaryContainer.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: cs.onSecondaryContainer, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg.replaceAll('Instance of ', ''),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.theme, required this.cs});

  final ThemeData theme;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 48),
      child: Column(
        children: [
          Icon(Icons.notifications_off_outlined, size: 56, color: cs.outline),
          const SizedBox(height: 16),
          Text(
            'Nessuna notifica',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Quando arrivano aggiornamenti su segnalazioni o raccolte, li vedrai qui.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.title,
    required this.body,
    required this.timeLabel,
    required this.read,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String body;
  final String timeLabel;
  final bool read;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Material(
        color: read ? cs.surface : cs.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: cs.primary.withValues(alpha: 0.12),
                  foregroundColor: cs.primary,
                  child: Icon(icon, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: read ? FontWeight.w500 : FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  timeLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
