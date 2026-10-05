import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../models/app_notification.dart';
import '../repositories/notification_repository.dart';
import '../routes.dart';
import '../state/app_session.dart';
import '../theme/app_colors.dart';
import 'classifica_screen.dart';
import 'mappa_screen.dart';
import 'profilo_screen.dart';
import '../theme/app_icons.dart';
import '../widgets/app_button.dart';

/// Contenitore principale: tab Mappa, Classifica, Profilo. Segnala si apre a
/// tutto schermo dal pulsante giallo della Mappa.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index;

  void _selectTab(int index) {
    if (index == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = index);
  }

  final _notificationRepository = FirestoreNotificationRepository();

  int _normalizedIndex(int value) => value.clamp(0, 2);

  @override
  void initState() {
    super.initState();
    _index = _normalizedIndex(widget.initialIndex);
  }

  @override
  void didUpdateWidget(covariant MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _index = _normalizedIndex(widget.initialIndex);
    }
  }

  static const _titles = ['Mappa', 'Classifica', 'Profilo'];

  /// Una sola tab alla volta nel tree: [IndexedStack] teneva tutte le schermate
  /// (inclusa [GoogleMap]) montate insieme e su Android creava più platform view
  /// e layout fragili. Qui la mappa esiste solo quando la tab Mappa è selezionata.
  Widget _bodyForTab(int i) {
    return switch (i) {
      0 => const MappaScreen(),
      1 => ClassificaScreen(),
      _ => const ProfiloScreen(),
    };
  }

  Widget _notificationsButton(BuildContext context) {
    final uid = AppSessionScope.watch(context).currentUserId;

    final icon = uid == null
        ? const Icon(AppIcons.notifications)
        : StreamBuilder<List<AppNotification>>(
            stream: _notificationRepository.watchUserNotifications(uid),
            builder: (context, snapshot) {
              final hasUnread = snapshot.data?.any((n) => !n.read) ?? false;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(AppIcons.notifications),
                  if (hasUnread)
                    Positioned(
                      top: -1,
                      right: -1,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: AppColors.redPin,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              );
            },
          );

    return IconButton(
      tooltip: 'Notifiche',
      icon: icon,
      onPressed: () => context.push(AppRoutes.notifiche),
    );
  }

  Widget _bottomNavBar(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      color: AppColors.forest,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: 80,
        child: Row(
          children: [
            for (final (i, item) in _navItems.indexed)
              Expanded(
                child: _NavBarItem(
                  icon: item.icon,
                  activeIcon: item.activeIcon,
                  label: item.label,
                  selected: _index == i,
                  onTap: () => _selectTab(i),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static const _navItems = [
    (icon: AppIcons.map, activeIcon: AppIcons.mapActive, label: 'Mappa'),
    (
      icon: AppIcons.leaderboard,
      activeIcon: AppIcons.leaderboardActive,
      label: 'Classifica',
    ),
    (
      icon: AppIcons.profile,
      activeIcon: AppIcons.profileActive,
      label: 'Profilo',
    ),
  ];

  // Header brand (logo + "Trashpotting") condiviso da Mappa e Segnala,
  // le due tab che nel mockup Figma mostrano il logo invece del nome tab.
  PreferredSizeWidget _brandAppBar(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      centerTitle: false,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/icons/logo_leaf_pin.svg',
            width: 20,
            height: 20,
          ),
          const SizedBox(width: 6),
          Text(
            'Trashpotting',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.greenBrand,
            ),
          ),
        ],
      ),
      actions: [_notificationsButton(context)],
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    if (_index == 0) {
      return _brandAppBar(context);
    }
    if (_index == 1) {
      // AppBar verde brand: stessa meccanica di sicurezza/spaziatura della
      // tab Mappa (Scaffold la posiziona già correttamente sotto la status
      // bar), solo colorata per continuare nell'hero gradiente sotto.
      return AppBar(
        backgroundColor: AppColors.greenBrand,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Classifica',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        actions: [_notificationsButton(context)],
      );
    }
    return AppBar(
      title: Text(_titles[_index]),
      actions: [_notificationsButton(context)],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: SizedBox.expand(child: _bodyForTab(_index)),
      bottomNavigationBar: _bottomNavBar(context),
      // Segnala è l'azione principale dell'app: pulsante giallo sulla Mappa.
      floatingActionButton: _index == 0
          ? Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: AppButton(
                label: 'Segnala',
                icon: AppIcons.addPlace,
                badge: '+1 pt',
                expand: false,
                onPressed: () => context.push(AppRoutes.segnala),
              ),
            )
          : null,
    );
  }
}

/// Voce della bottom bar: su verde foresta, la voce attiva ha l'icona in una
/// pillola gialla e l'etichetta bianca.
class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Semantics(
      selected: selected,
      button: true,
      child: InkResponse(
        onTap: onTap,
        radius: 44,
        highlightColor: Colors.transparent,
        splashColor: Colors.white.withAlpha(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: 64,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.yellow : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                selected ? activeIcon : icon,
                size: 22,
                color: selected ? AppColors.onYellow : AppColors.mintText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                height: 16 / 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? Colors.white : AppColors.mintText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
