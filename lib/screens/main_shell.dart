import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../models/app_notification.dart';
import '../repositories/notification_repository.dart';
import '../routes.dart';
import '../state/app_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import 'classifica_screen.dart';
import 'mappa_screen.dart';
import 'profilo_screen.dart';
import 'segnala_screen.dart';

/// Contenitore principale: tab Mappa, Segnala, Profilo.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index;
  final _notificationRepository = FirestoreNotificationRepository();

  int _normalizedIndex(int value) => value.clamp(0, 3);

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

  static const _titles = ['Mappa', 'Segnala', 'Classifica', 'Profilo'];

  /// Una sola tab alla volta nel tree: [IndexedStack] teneva tutte le schermate
  /// (inclusa [GoogleMap]) montate insieme e su Android creava più platform view
  /// e layout fragili. Qui la mappa esiste solo quando la tab Mappa è selezionata.
  Widget _bodyForTab(int i) {
    return switch (i) {
      0 => const MappaScreen(),
      1 => SegnalaScreen(),
      2 => ClassificaScreen(),
      _ => const ProfiloScreen(),
    };
  }

  Widget _notificationsButton(BuildContext context) {
    final uid = AppSessionScope.watch(context).currentUserId;

    final icon = uid == null
        ? const Icon(Icons.notifications_outlined)
        : StreamBuilder<List<AppNotification>>(
            stream: _notificationRepository.watchUserNotifications(uid),
            builder: (context, snapshot) {
              final hasUnread = snapshot.data?.any((n) => !n.read) ?? false;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_outlined),
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
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: context.palette.divider, width: 0.5),
        ),
      ),
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            Expanded(
              child: _NavBarItem(
                asset: 'assets/icons/nav_map.svg',
                label: 'Mappa',
                selected: _index == 0,
                onTap: () => setState(() => _index = 0),
              ),
            ),
            Expanded(
              child: _SegnalaFabItem(
                selected: _index == 1,
                onTap: () => setState(() => _index = 1),
              ),
            ),
            Expanded(
              child: _NavBarItem(
                asset: 'assets/icons/nav_leaderboard.svg',
                label: 'Classifica',
                selected: _index == 2,
                onTap: () => setState(() => _index = 2),
              ),
            ),
            Expanded(
              child: _NavBarItem(
                asset: 'assets/icons/nav_profile.svg',
                label: 'Profilo',
                selected: _index == 3,
                onTap: () => setState(() => _index = 3),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
    if (_index == 0 || _index == 1) {
      return _brandAppBar(context);
    }
    if (_index == 2) {
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
    );
  }
}

/// Voce standard della bottom bar: icona in pillola (verde chiara se
/// selezionata) + label, come da mockup.
class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.asset,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String asset;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = selected
        ? AppColors.greenBrand
        : context.palette.textDisabled;
    return InkResponse(
      onTap: onTap,
      radius: 40,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? context.palette.greenLight : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: SvgPicture.asset(
              asset,
              width: 22,
              height: 22,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected
                  ? (Theme.of(context).brightness == Brightness.dark
                        ? AppColors.greenBrand
                        : AppColors.greenDark)
                  : context.palette.textDisabled,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Voce centrale "Segnala": FAB circolare verde rialzato di 8px che rompe
/// il bordo superiore della bottom bar, come da design brief.
class _SegnalaFabItem extends StatelessWidget {
  const _SegnalaFabItem({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.translate(
        offset: const Offset(0, -8),
        child: Semantics(
          label: 'Segnala',
          button: true,
          selected: selected,
          child: Material(
            color: AppColors.greenBrand,
            shape: const CircleBorder(
              side: BorderSide(color: Colors.white, width: 3),
            ),
            elevation: 0,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.greenBrand.withAlpha(90),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_location_alt,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
