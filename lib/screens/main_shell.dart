import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../routes.dart';
import 'mappa_screen.dart';
import 'profilo_screen.dart';
import 'segnala_screen.dart';

/// Contenitore principale: tab Mappa, Segnala, Profilo.
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    this.initialIndex = 0,
  });

  final int initialIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index;

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

  static const _titles = ['Mappa', 'Segnala', 'Profilo'];

  /// Una sola tab alla volta nel tree: [IndexedStack] teneva tutte le schermate
  /// (inclusa [GoogleMap]) montate insieme e su Android creava più platform view
  /// e layout fragili. Qui la mappa esiste solo quando la tab Mappa è selezionata.
  Widget _bodyForTab(int i) {
    return switch (i) {
      0 => const MappaScreen(),
      1 => SegnalaScreen(),
      _ => const ProfiloScreen(),
    };
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
              context.push(AppRoutes.notifiche);
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
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profilo',
          ),
        ],
      ),
    );
  }
}
