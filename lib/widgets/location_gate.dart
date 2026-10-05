import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import 'app_button.dart';
import 'illustration.dart';

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
              onRetry: _check,
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
    required this.onRetry,
    required this.onSignOut,
  });

  final _LocationStatus status;
  final bool busy;
  final VoidCallback onFix;
  final VoidCallback onRetry;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final (badge, title, message, action) = switch (status) {
      _LocationStatus.serviceOff => (
        'Posizione disattivata',
        'Attiva la posizione',
        'Ci serve per mostrarti i rifiuti vicino a te e per registrare dove '
            'si trovano quelli che segnali.',
        'Apri le impostazioni',
      ),
      _LocationStatus.denied => (
        'Permesso mancante',
        'Consenti la posizione',
        'Per segnalare rifiuti e vedere quelli vicino a te, Trashpotting ha '
            'bisogno del permesso di accedere alla tua posizione.',
        'Consenti accesso',
      ),
      _ => (
        'Permesso negato',
        'Riattiva il permesso',
        'Nelle impostazioni dell\'app vai su Autorizzazioni → Posizione e '
            'scegli "Consenti solo mentre usi l\'app".',
        'Apri le impostazioni',
      ),
    };

    return Material(
      color: AppColors.bgAlt,
      child: IllustratedMessage(
        illustration: const MultiplyImage(
          asset: 'assets/onboarding/posizione.png',
        ),
        badge: (
          icon: AppIcons.myLocation,
          label: badge,
          bg: AppColors.yellowLight,
          fg: AppColors.yellowText,
        ),
        title: title,
        message: message,
        note: const IllustratedNote(
          icon: AppIcons.lock,
          text:
              'La usiamo solo mentre usi l\'app. Gli altri non vedono mai '
              'dove sei.',
          bg: AppColors.purpleLight,
          fg: AppColors.purpleDark,
        ),
        primary: AppButton(
          label: action,
          icon: AppIcons.settings,
          loading: busy,
          onPressed: onFix,
        ),
        secondary: [
          TextButton(
            onPressed: busy ? null : onRetry,
            style: TextButton.styleFrom(foregroundColor: AppColors.greenDark),
            child: const Text('Riprova'),
          ),
          TextButton(
            onPressed: busy ? null : onSignOut,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text('Esci dall\'account'),
          ),
        ],
      ),
    );
  }
}
