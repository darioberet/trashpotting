import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_icons.dart';

enum _LocationStatus { checking, ok, serviceOff, denied, deniedForever }

/// Blocca l'uso dell'app finché GPS e permesso di posizione non sono attivi:
/// segnalazioni e mappa dipendono dalla posizione.
///
/// Il blocco è un overlay sopra [child] (non lo sostituisce), così lo stack
/// di navigazione resta intatto e l'app riprende da dov'era. Lo stato si
/// ricontrolla al ritorno dalle impostazioni e quando cambia lo stato del
/// GPS.
class LocationGate extends StatefulWidget {
  const LocationGate({
    super.key,
    required this.enabled,
    required this.onSignOut,
    required this.child,
  });

  /// Falso per le schermate che devono restare usabili senza posizione
  /// (login, registrazione, verifica email, onboarding).
  final bool enabled;
  final Future<void> Function() onSignOut;
  final Widget child;

  @override
  State<LocationGate> createState() => _LocationGateState();
}

class _LocationGateState extends State<LocationGate>
    with WidgetsBindingObserver {
  _LocationStatus _status = _LocationStatus.checking;
  StreamSubscription<ServiceStatus>? _serviceSub;
  bool _requesting = false;

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    if (!_supported) return;
    WidgetsBinding.instance.addObserver(this);
    _serviceSub = Geolocator.getServiceStatusStream().listen(
      (_) => _check(),
      onError: (_) {},
    );
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _serviceSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final _LocationStatus status;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        status = _LocationStatus.serviceOff;
      } else {
        status = switch (await Geolocator.checkPermission()) {
          LocationPermission.denied => _LocationStatus.denied,
          LocationPermission.deniedForever => _LocationStatus.deniedForever,
          _ => _LocationStatus.ok,
        };
      }
    } catch (_) {
      // Plugin non disponibile: non bloccare l'utente per un nostro errore.
      if (mounted) setState(() => _status = _LocationStatus.ok);
      return;
    }
    if (mounted && status != _status) setState(() => _status = status);
  }

  Future<void> _fix() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    try {
      switch (_status) {
        case _LocationStatus.serviceOff:
          await Geolocator.openLocationSettings();
        case _LocationStatus.denied:
          await Geolocator.requestPermission();
        case _LocationStatus.deniedForever:
          await Geolocator.openAppSettings();
        case _LocationStatus.checking || _LocationStatus.ok:
          break;
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
      await _check();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Durante il primo controllo si mostra l'app (ottimistico): evita un
    // lampo della schermata di blocco a chi ha già tutto attivo.
    final blocked =
        _supported &&
        widget.enabled &&
        _status != _LocationStatus.ok &&
        _status != _LocationStatus.checking;

    return Stack(
      children: [
        widget.child,
        if (blocked)
          Positioned.fill(
            child: _BlockedView(
              status: _status,
              busy: _requesting,
              onFix: _fix,
              onSignOut: widget.onSignOut,
            ),
          ),
      ],
    );
  }
}

class _BlockedView extends StatelessWidget {
  const _BlockedView({
    required this.status,
    required this.busy,
    required this.onFix,
    required this.onSignOut,
  });

  final _LocationStatus status;
  final bool busy;
  final VoidCallback onFix;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    final (title, message, action) = switch (status) {
      _LocationStatus.serviceOff => (
        'Attiva la posizione',
        'Trashpotting usa il GPS per mostrarti le segnalazioni vicine e per '
            'registrare dove si trovano i rifiuti. Attiva la localizzazione '
            'per continuare.',
        'Attiva GPS',
      ),
      _LocationStatus.denied => (
        'Consenti l\'accesso alla posizione',
        'Per segnalare rifiuti e vedere quelli vicino a te, Trashpotting ha '
            'bisogno del permesso di accedere alla tua posizione.',
        'Consenti accesso',
      ),
      _ => (
        'Permesso di posizione negato',
        'Hai negato il permesso di posizione. Aprendo le impostazioni '
            'dell\'app, vai su Autorizzazioni → Posizione e scegli '
            '"Consenti solo mentre usi l\'app".',
        'Apri impostazioni',
      ),
    };

    return Material(
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
                  color: palette.greenLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  AppIcons.locationOff,
                  size: 44,
                  color: AppColors.greenBrand,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.textSecondary,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: busy ? null : onFix,
                  icon: const Icon(AppIcons.myLocation),
                  label: Text(action),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: busy ? null : onSignOut,
                child: const Text('Esci dall\'account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
