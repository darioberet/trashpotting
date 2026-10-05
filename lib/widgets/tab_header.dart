import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/app_notification.dart';
import '../repositories/leaderboard_repository.dart';
import '../repositories/notification_repository.dart';
import '../routes.dart';
import '../state/app_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';

/// Header delle tab principali (Mappa, Classifica, Profilo): riquadro verde
/// con la foglia, titolo grande e azioni a destra. Prende il posto
/// dell'AppBar, così può stare sopra la mappa o su uno sfondo colorato.
class TabHeader extends StatelessWidget {
  const TabHeader({
    super.key,
    required this.title,
    this.actions = const [],
    this.onDark = false,
  });

  final String title;
  final List<Widget> actions;

  /// Titolo bianco, per gli header su verde foresta (Classifica).
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          const BrandTile(),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 26,
                  height: 32 / 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: onDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ),
          for (final (i, action) in actions.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            action,
          ],
        ],
      ),
    );
  }
}

/// Logo compatto: foglia bianca su riquadro verde brand.
class BrandTile extends StatelessWidget {
  const BrandTile({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.greenBrand,
          borderRadius: BorderRadius.circular(size / 3),
        ),
        child: Icon(AppIcons.leaf, size: size * 0.55, color: Colors.white),
      ),
    );
  }
}

/// Pulsante tondo dell'header (campanella, impostazioni…).
class HeaderCircleButton extends StatelessWidget {
  const HeaderCircleButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.onDark = false,
    this.badge = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool onDark;

  /// Pallino rosso (es. notifiche non lette).
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final bg = onDark ? Colors.white.withAlpha(26) : Colors.white;
    final fg = onDark ? Colors.white : AppColors.textPrimary;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: badge ? '$tooltip, ci sono novità' : tooltip,
        excludeSemantics: true,
        child: Material(
          color: bg,
          shape: const CircleBorder(),
          elevation: 0,
          shadowColor: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: onDark
                  ? null
                  : BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.textPrimary.withAlpha(30),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 22, color: fg),
                  if (badge)
                    Positioned(
                      top: -1,
                      right: -1,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.redPin,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: bg.withAlpha(255),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Campanella delle notifiche, con il pallino se ce ne sono di non lette.
class NotificationsBell extends StatefulWidget {
  const NotificationsBell({super.key, this.onDark = false});

  final bool onDark;

  @override
  State<NotificationsBell> createState() => _NotificationsBellState();
}

class _NotificationsBellState extends State<NotificationsBell> {
  final _repository = FirestoreNotificationRepository();

  // Lo stream si riapre solo se cambia l'utente, non a ogni ricostruzione.
  String? _uid;
  Stream<List<AppNotification>>? _stream;

  @override
  Widget build(BuildContext context) {
    final uid = AppSessionScope.watch(context).currentUserId;
    if (uid != _uid) {
      _uid = uid;
      _stream = uid == null ? null : _repository.watchUserNotifications(uid);
    }
    void open() => context.push(AppRoutes.notifiche);
    return StreamBuilder<List<AppNotification>>(
      stream: _stream,
      builder: (context, snapshot) => HeaderCircleButton(
        icon: AppIcons.notifications,
        tooltip: 'Notifiche',
        onDark: widget.onDark,
        badge: snapshot.data?.any((n) => !n.read) ?? false,
        onPressed: open,
      ),
    );
  }
}

/// Pillola gialla con la stellina e i punti dell'utente; porta alla
/// Classifica.
class PointsPill extends StatefulWidget {
  const PointsPill({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  State<PointsPill> createState() => _PointsPillState();
}

class _PointsPillState extends State<PointsPill> {
  final _repository = FirestoreLeaderboardRepository();
  String? _uid;
  Stream<int>? _stream;

  @override
  Widget build(BuildContext context) {
    final uid = AppSessionScope.watch(context).currentUserId;
    if (uid != _uid) {
      _uid = uid;
      _stream = uid == null ? null : _repository.watchUserPoints(uid);
    }
    final onTap = widget.onTap;
    return StreamBuilder<int>(
      stream: _stream,
      builder: (context, snapshot) {
        final points = snapshot.data;
        if (points == null) return const SizedBox.shrink();
        return Semantics(
          button: onTap != null,
          label: 'I tuoi punti: $points',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              height: 40,
              constraints: const BoxConstraints(minWidth: 48),
              padding: const EdgeInsets.only(left: 8, right: 12),
              decoration: BoxDecoration(
                color: AppColors.yellow,
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(color: AppColors.yellowEdge, offset: Offset(0, 3)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    AppIcons.starFilled,
                    size: 18,
                    color: AppColors.onYellow,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$points',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onYellow,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Header delle pagine secondarie: pulsante tondo "indietro" e titolo.
class BackHeader extends StatelessWidget {
  const BackHeader({super.key, required this.title, this.actions = const []});

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            HeaderCircleButton(
              icon: AppIcons.back,
              tooltip: 'Indietro',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 24,
                    height: 30 / 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            for (final action in actions) ...[const SizedBox(width: 8), action],
          ],
        ),
      ),
    );
  }
}
