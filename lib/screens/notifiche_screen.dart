import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/time_format.dart';
import '../models/app_notification.dart';
import '../repositories/notification_repository.dart';
import '../routes.dart';
import '../state/app_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../widgets/illustration.dart';
import '../widgets/skeleton.dart';
import '../widgets/tab_header.dart';

/// Notifiche dell'utente (`users/{uid}/notifications`, scritte dalle Cloud
/// Functions). Toccarne una la segna come letta e apre la segnalazione.
class NotificheScreen extends StatefulWidget {
  NotificheScreen({super.key, NotificationRepository? repository})
    : _repository = repository ?? FirestoreNotificationRepository();

  final NotificationRepository _repository;

  @override
  State<NotificheScreen> createState() => _NotificheScreenState();
}

class _NotificheScreenState extends State<NotificheScreen> {
  // Memorizzato: ricrearlo a ogni build riaprirebbe la query.
  String? _uid;
  Stream<List<AppNotification>>? _stream;

  Future<void> _open(String uid, AppNotification n) async {
    final session = AppSessionScope.of(context);
    final reportId = n.reportId;
    if (reportId != null && reportId.isNotEmpty) {
      context.push('${AppRoutes.reportDetail}/$reportId');
    }
    if (n.read) return;
    try {
      await widget._repository.markRead(uid: uid, notificationId: n.id);
    } catch (e) {
      session.publishError(e, fallback: 'Impossibile aggiornare la notifica.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppSessionScope.watch(context).currentUserId;
    if (uid != _uid) {
      _uid = uid;
      _stream = uid == null
          ? null
          : widget._repository.watchUserNotifications(uid);
    }

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
              const BackHeader(title: 'Notifiche'),
              Expanded(
                child: uid == null
                    ? const _Message(
                        icon: AppIcons.notifications,
                        title: 'Accedi per vedere le notifiche',
                        message:
                            'Qui trovi gli aggiornamenti sulle tue segnalazioni '
                            'e sugli eventi a cui partecipi.',
                      )
                    : StreamBuilder<List<AppNotification>>(
                        stream: _stream,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const _Message(
                              icon: AppIcons.offline,
                              title: 'Impossibile caricare le notifiche',
                              message:
                                  'Controlla la connessione e riapri la pagina.',
                            );
                          }
                          if (!snapshot.hasData) {
                            return const SkeletonList(
                              padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                              thumbSize: 44,
                              circleThumb: true,
                            );
                          }
                          final items = snapshot.data!;
                          if (items.isEmpty) return const _EmptyMessage();
                          return ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              8,
                              16,
                              16 + MediaQuery.of(context).padding.bottom,
                            ),
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) => _NotificationCard(
                              notification: items[i],
                              onTap: () => _open(uid, items[i]),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icona e colori per tipo di notifica (vedi functions/index.js).
({IconData icon, Color bg, Color fg}) _styleFor(String? type) => switch (type) {
  'report_cleaned' => (
    icon: AppIcons.statusCleaned,
    bg: AppColors.greenStatusLight,
    fg: AppColors.greenStatusText,
  ),
  'event_reminder' => (
    icon: AppIcons.calendar,
    bg: AppColors.blueLight,
    fg: AppColors.blueText,
  ),
  'nearby_report' => (
    icon: AppIcons.place,
    bg: AppColors.redLight,
    fg: AppColors.redText,
  ),
  _ => (
    icon: AppIcons.notifications,
    bg: AppColors.greenLight,
    fg: AppColors.greenDark,
  ),
};

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final style = _styleFor(n.type);
    final at = n.createdAt;
    return Material(
      // Le non lette spiccano: sfondo bianco e pallino; le lette si
      // confondono con lo sfondo crema.
      color: n.read ? AppColors.bgAlt : Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: n.read ? AppColors.mintBorder : Colors.transparent,
            ),
            boxShadow: n.read
                ? null
                : const [
                    BoxShadow(
                      color: AppColors.mintBorder,
                      offset: Offset(0, 2),
                    ),
                  ],
          ),
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: style.bg,
                  shape: BoxShape.circle,
                ),
                child: Icon(style.icon, size: 22, color: style.fg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            n.title,
                            style: TextStyle(
                              fontSize: 15,
                              height: 20 / 15,
                              fontWeight: n.read
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (at != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            relativeTimeLabel(at),
                            style: const TextStyle(
                              fontSize: 12,
                              height: 20 / 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        if (!n.read) ...[
                          const SizedBox(width: 6),
                          Semantics(
                            label: 'Non letta',
                            child: Container(
                              margin: const EdgeInsets.only(top: 6),
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.greenBrand,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (n.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        n.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 20 / 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
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

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage();

  @override
  Widget build(BuildContext context) {
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: const IllustratedMessage(
        illustration: Center(
          child: Icon(
            AppIcons.notificationsOff,
            size: 96,
            color: AppColors.greenBrand,
          ),
        ),
        title: 'Nessuna notifica',
        message:
            'Qui arrivano gli aggiornamenti: quando una tua segnalazione viene '
            'ripulita, il promemoria degli eventi e i nuovi rifiuti vicino a te.',
      ),
    );
  }
}

/// Messaggio centrato per gli stati senza lista (non loggato, errore).
class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: IllustratedMessage(
        illustration: Center(
          child: Icon(icon, size: 96, color: AppColors.greenBrand),
        ),
        title: title,
        message: message,
      ),
    );
  }
}
