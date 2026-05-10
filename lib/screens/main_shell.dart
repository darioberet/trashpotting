import 'package:flutter/material.dart';

import '../routes.dart';
import 'classifica_screen.dart';
import 'mappa_screen.dart';
import 'profilo_screen.dart';
import 'segnala_screen.dart';

/// Contenitore principale: tab Mappa, Segnala, Classifica, Profilo.
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.firebaseReady,
    this.firebaseError,
    this.initialIndex = 0,
  });

  final bool firebaseReady;
  final Object? firebaseError;
  final int initialIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, 3);
  }

  static const _titles = ['Mappa', 'Segnala', 'Classifica', 'Profilo'];

  /// Una sola tab alla volta nel tree: [IndexedStack] teneva tutte le schermate
  /// (inclusa [GoogleMap]) montate insieme e su Android creava più platform view
  /// e layout fragili. Qui la mappa esiste solo quando la tab Mappa è selezionata.
  Widget _bodyForTab(int i) {
    switch (i) {
      case 0:
        return const MappaScreen();
      case 1:
        return const SegnalaScreen();
      case 2:
        return const ClassificaScreen();
      case 3:
        return ProfiloScreen(
          firebaseReady: widget.firebaseReady,
          firebaseError: widget.firebaseError,
        );
      default:
        return const MappaScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          IconButton(
            tooltip: 'Notifiche',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.of(context).pushNamed<void>(AppRoutes.notifiche);
            },
          ),
        ],
      ),
      body: SizedBox.expand(child: _bodyForTab(_index)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Mappa',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_location_alt_outlined),
            selectedIcon: Icon(Icons.add_location_alt),
            label: 'Segnala',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: 'Classifica',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profilo',
          ),
        ],
      ),
    );
  }
}
