import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/geo_utils.dart';
import '../core/map_style.dart';
import '../core/marker_clustering.dart';
import '../core/marker_icons.dart';
import '../core/time_format.dart';
import '../maps_android_init.dart';
import '../models/report_filter.dart';
import '../models/trashpot_report.dart';
import '../repositories/leaderboard_repository.dart' show pointsPerCleanup;
import '../repositories/report_repository.dart';
import '../routes.dart';
import '../services/location_service.dart';
import '../services/push_service.dart';
import '../widgets/skeleton.dart';
import '../widgets/tab_header.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_icons.dart';

class MappaScreen extends StatefulWidget {
  const MappaScreen({super.key});

  @override
  State<MappaScreen> createState() => _MappaScreenState();
}

class _MappaScreenState extends State<MappaScreen> {
  GoogleMapController? _mapController;
  final _locationService = LocationService();
  final _reportRepository = FirestoreReportRepository();
  bool _resolvingGps = false;
  LatLng? _initialTarget;
  LatLng? _userPosition;
  bool _mapMountReady = false;

  Set<Marker> _displayMarkers = {};
  List<TrashpotReport> _lastReports = const [];
  String? _lastMarkersSignature;
  int _clusterEpoch = 0;

  static const _fallbackTarget = LatLng(42.5, 12.5); // centro Italia
  static const _radiusPrefsKey = 'map_radius_km';
  // v2: con il gruppo "Evento" separato da "In corso".
  static const _statusPrefsKey = 'map_status_groups_v2';
  final _preferences = SharedPreferencesAsync();
  int _radiusKm = defaultReportRadiusKm;
  Set<ReportStatusGroup> _statusGroups = {...defaultReportStatusGroups};

  // Lo stream va memorizzato: ricrearlo a ogni build (es. dopo il
  // setState del clustering) riaprirebbe tutte le query Firestore.
  Stream<List<TrashpotReport>>? _reportsStream;
  String? _reportsStreamKey;

  Stream<List<TrashpotReport>> _reportsStreamFor(LatLng? center) {
    // Gli stati fanno parte della chiave: cambiando filtro si riapre la
    // query, perché è Firestore a filtrare (gli stati esclusi non si leggono).
    final groups = (_statusGroups.map((g) => g.name).toList()..sort()).join();
    final key = center == null
        ? 'recent'
        : '${center.latitude},${center.longitude},$_radiusKm,$groups';
    if (key != _reportsStreamKey || _reportsStream == null) {
      _reportsStreamKey = key;
      _reportsStream = center == null
          ? _reportRepository.watchReports()
          : _reportRepository.watchReportsNear(
              latitude: center.latitude,
              longitude: center.longitude,
              radiusKm: _radiusKm.toDouble(),
              statusGroups: _statusGroups,
            );
    }
    return _reportsStream!;
  }

  Future<void> _loadFilters() async {
    try {
      final radius = await _preferences.getInt(_radiusPrefsKey);
      final groups = await _preferences.getStringList(_statusPrefsKey);
      if (!mounted) return;
      setState(() {
        if (radius != null && reportRadiusOptionsKm.contains(radius)) {
          _radiusKm = radius;
        }
        if (groups != null) {
          _statusGroups = ReportStatusGroup.values
              .where((g) => groups.contains(g.name))
              .toSet();
        }
      });
    } catch (_) {
      // Preferenze non disponibili: restano i filtri predefiniti.
    }
  }

  void _setRadius(int km) {
    if (km == _radiusKm) return;
    setState(() => _radiusKm = km);
    _preferences.setInt(_radiusPrefsKey, km).ignore();
    _fitRadius();
  }

  void _setStatusGroups(Set<ReportStatusGroup> groups) {
    setState(() => _statusGroups = {...groups});
    _preferences
        .setStringList(
          _statusPrefsKey,
          _statusGroups.map((g) => g.name).toList(),
        )
        .ignore();
  }

  /// Inquadra il cerchio del raggio di ricerca attorno all'utente.
  Future<void> _fitRadius() async {
    final c = _mapController;
    final center = _userPosition;
    if (c == null || center == null) return;
    final latDelta = _radiusKm / 110.574;
    final lngDelta =
        _radiusKm / (111.320 * math.cos(center.latitude * math.pi / 180));
    try {
      await c.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              center.latitude - latDelta,
              center.longitude - lngDelta,
            ),
            northeast: LatLng(
              center.latitude + latDelta,
              center.longitude + lngDelta,
            ),
          ),
          24,
        ),
      );
    } catch (_) {}
  }

  static bool get _googleMapsAvailable {
    if (kIsWeb) return true;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      default:
        return false;
    }
  }

  LatLngBounds? _boundsForReports(Iterable<TrashpotReport> reports) {
    if (reports.isEmpty) return null;
    final pts = reports.map((r) => LatLng(r.lat, r.lng)).toList();
    var south = pts.first.latitude;
    var north = pts.first.latitude;
    var west = pts.first.longitude;
    var east = pts.first.longitude;
    for (final p in pts) {
      south = south < p.latitude ? south : p.latitude;
      north = north > p.latitude ? north : p.latitude;
      west = west < p.longitude ? west : p.longitude;
      east = east > p.longitude ? east : p.longitude;
    }
    const pad = 0.012;
    return LatLngBounds(
      southwest: LatLng(south - pad, west - pad),
      northeast: LatLng(north + pad, east + pad),
    );
  }

  MapType _mapType = MapType.normal;

  void _toggleMapType() {
    HapticFeedback.selectionClick();
    setState(
      () => _mapType = _mapType == MapType.normal
          ? MapType.hybrid
          : MapType.normal,
    );
  }

  /// Il colore del marker dice lo stato; l'icona dice il tipo di rifiuto
  /// finché c'è da pulire, poi l'avanzamento (evento, pulizia, ripulita).
  IconData _markerIcon(TrashpotReport r) {
    return switch (r.status) {
      TrashpotStatus.segnalata ||
      TrashpotStatus.aperta ||
      TrashpotStatus.inLavorazione => AppIcons.forWasteType(r.typeLabel),
      TrashpotStatus.eventoCreato => AppIcons.markerEvent,
      TrashpotStatus.puliziaInCorso => AppIcons.markerCleaning,
      TrashpotStatus.pulita ||
      TrashpotStatus.ripulita => AppIcons.markerCleaned,
      TrashpotStatus.sparita => AppIcons.markerGone,
    };
  }

  void _openReportDetails(String reportId) =>
      context.push('${AppRoutes.reportDetail}/$reportId');

  Future<void> _fitReports(Iterable<TrashpotReport> reports) async {
    final c = _mapController;
    if (c == null) return;
    final bounds = _boundsForReports(reports);
    if (bounds == null) return;
    try {
      await c.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    } catch (_) {}
  }

  /// Tap su un gruppo: centra e avvicina di due livelli. Inquadrare i punti
  /// del gruppo non basta: con segnalazioni a poche centinaia di metri il
  /// margine di [_boundsForReports] lascia lo zoom invariato.
  Future<void> _zoomIntoCluster(LatLng center) async {
    final c = _mapController;
    if (c == null) return;
    try {
      final zoom = await c.getZoomLevel();
      await c.animateCamera(
        CameraUpdate.newLatLngZoom(center, math.min(zoom + 2, 19)),
      );
    } catch (_) {}
  }

  /// Ricalcola i marker raggruppando (clustering) le segnalazioni vicine
  /// sullo schermo alla zoom/posizione corrente. Va rieseguito quando
  /// cambiano i dati o quando l'utente sposta/zooma la mappa
  /// ([onCameraIdle]), perché la distanza in pixel tra due punti dipende
  /// dal livello di zoom.
  Future<void> _recomputeMarkers(List<TrashpotReport> reports) async {
    final controller = _mapController;
    _lastReports = reports;
    if (controller == null || reports.isEmpty) {
      if (mounted) setState(() => _displayMarkers = {});
      return;
    }

    final epoch = ++_clusterEpoch;
    List<ScreenCoordinate> coords;
    try {
      coords = await Future.wait(
        reports.map(
          (r) => controller.getScreenCoordinate(LatLng(r.lat, r.lng)),
        ),
      );
    } catch (_) {
      return;
    }
    if (!mounted || epoch != _clusterEpoch) return;

    final groups = clusterByScreenDistance<TrashpotReport>(
      items: reports,
      screenPoints: coords,
      positionOf: (r) => LatLng(r.lat, r.lng),
    );

    final markers = <Marker>{};
    for (final group in groups) {
      if (group.isCluster) {
        final counts = <Color, int>{};
        for (final r in group.items) {
          final color = AppColors.statusColor(r.status);
          counts[color] = (counts[color] ?? 0) + 1;
        }
        final icon = await MarkerIconFactory.cluster(countsByColor: counts);
        if (!mounted || epoch != _clusterEpoch) return;
        markers.add(
          Marker(
            markerId: MarkerId(
              'cluster_${group.center.latitude}_${group.center.longitude}_${group.items.length}',
            ),
            position: group.center,
            icon: icon,
            anchor: const Offset(0.5, 0.5),
            onTap: () => _zoomIntoCluster(group.center),
          ),
        );
      } else {
        final r = group.items.first;
        final color = AppColors.statusColor(r.status);
        final icon = await MarkerIconFactory.pin(
          color: color,
          icon: _markerIcon(r),
          // Sull'arancio l'icona bianca non ha contrasto sufficiente.
          iconColor: color == AppColors.amberDot
              ? const Color(0xFF3A1A00)
              : Colors.white,
        );
        if (!mounted || epoch != _clusterEpoch) return;
        markers.add(
          Marker(
            markerId: MarkerId('tp_${r.id}'),
            position: LatLng(r.lat, r.lng),
            icon: icon,
            anchor: MarkerIconFactory.pinAnchor,
            onTap: () => _openReportDetails(r.id),
            infoWindow: InfoWindow(
              title: r.title,
              snippet: trashpotStatusLabel(r.status),
            ),
          ),
        );
      }
    }

    if (mounted) setState(() => _displayMarkers = markers);
  }

  Future<void> _resolveInitialPosition() async {
    try {
      final p = await _locationService.getCurrentPosition();
      if (!mounted) return;
      final pos = LatLng(p.latitude, p.longitude);
      setState(() {
        _initialTarget = pos;
        _userPosition = pos;
      });
      unawaited(
        PushService.instance.updateApproximateLocation(p.latitude, p.longitude),
      );
    } catch (_) {
      if (!mounted) return;
      // Senza GPS si parte dall'Italia, non da (0,0) in mezzo all'oceano.
      setState(() => _initialTarget ??= _fallbackTarget);
    }
  }

  Future<void> _goToCurrentGpsPosition() async {
    if (_resolvingGps) return;
    final c = _mapController;
    if (c == null) return;

    setState(() => _resolvingGps = true);
    try {
      final p = await _locationService.getCurrentPosition();
      if (!mounted) return;
      final pos = LatLng(p.latitude, p.longitude);
      setState(() => _userPosition = pos);
      await c.animateCamera(CameraUpdate.newLatLngZoom(pos, 16));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('GPS non disponibile: $e')));
    } finally {
      if (mounted) setState(() => _resolvingGps = false);
    }
  }

  @override
  void initState() {
    super.initState();
    final deferMapMount =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    _mapMountReady = !deferMapMount;
    if (deferMapMount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await ensureAndroidMapsSdkReady();
          await Future<void>.delayed(const Duration(milliseconds: 120));
          if (mounted) setState(() => _mapMountReady = true);
        });
      });
    }
    _loadFilters();
    _resolveInitialPosition();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _mapController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Niente AppBar sulla Mappa: header e status bar stanno sopra la mappa
    // chiara, quindi icone di sistema scure.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (!_googleMapsAvailable) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(AppIcons.map, size: 64, color: AppColors.greenBrand),
              const SizedBox(height: 16),
              Text(
                'Google Maps è disponibile su Android, iOS e web.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Esegui l\'app su emulatore/dispositivo o Chrome per vedere la mappa.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_initialTarget == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<List<TrashpotReport>>(
      stream: _reportsStreamFor(_userPosition),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AppIcons.offline,
                      size: 48,
                      color: context.palette.textSecondary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Errore di rete. Riavvia l\'app o verifica la connessione.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        final isStreamLoading =
            snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;
        final rawReports = snapshot.data ?? const <TrashpotReport>[];
        final userPos = _userPosition;
        // Con la posizione, lo stream è già limitato al raggio e ordinato
        // per distanza; senza, mostra le più recenti.
        final reports = rawReports
            .where(
              (r) => _statusGroups.contains(ReportStatusGroup.of(r.status)),
            )
            .toList();
        final counts = <ReportStatusGroup, int>{
          for (final g in _statusGroups) g: 0,
        };
        for (final r in reports) {
          final g = ReportStatusGroup.of(r.status);
          if (g != null) counts[g] = (counts[g] ?? 0) + 1;
        }
        final countLabel = reports.length == 1
            ? '1 segnalazione'
            : '${reports.length} segnalazioni';
        final subtitle = userPos == null
            ? '$countLabel recenti · posizione non disponibile'
            : '$countLabel entro $_radiusKm km';
        final allStatuses =
            _statusGroups.length == ReportStatusGroup.values.length;
        final emptyMessage = userPos == null
            ? 'Nessuna segnalazione con questi filtri.'
            : allStatuses
            ? 'Nessuna segnalazione entro $_radiusKm km.\n'
                  'Prova ad allargare il raggio.'
            : 'Nessuna segnalazione entro $_radiusKm km con questi filtri.\n'
                  'Prova ad allargare il raggio o a scegliere altri stati.';

        // Il clustering dipende dallo zoom corrente (distanza in pixel),
        // quindi va ricalcolato quando cambia la lista segnalazioni — non
        // durante il build, ma dopo il frame, per non innescare un
        // setState mentre si sta già costruendo l'albero dei widget.
        final signature = reports
            .map((r) => '${r.id}:${r.status}:${r.lat}:${r.lng}')
            .join('|');
        if (signature != _lastMarkersSignature) {
          _lastMarkersSignature = signature;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _recomputeMarkers(reports);
          });
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final topInset = MediaQuery.of(context).padding.top;
            // Il pannello copre la parte bassa della mappa; i suoi angoli
            // arrotondati lasciano intravedere la mappa sotto.
            final panelHeight = constraints.maxHeight * 0.5;
            const panelOverlap = 28.0;
            final headerBottom = topInset + 12 + 56;

            return Stack(
              children: [
                Positioned.fill(
                  bottom: panelHeight - panelOverlap,
                  child: _mapMountReady
                      ? GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: _initialTarget!,
                            zoom: _userPosition == null ? 5.5 : 13,
                          ),
                          // Il centro e i bordi della mappa tengono conto
                          // dell'header sopra e degli angoli del pannello.
                          padding: EdgeInsets.only(
                            top: headerBottom,
                            bottom: panelOverlap,
                          ),
                          markers: _displayMarkers,
                          circles: {
                            if (userPos != null)
                              Circle(
                                circleId: const CircleId('search_radius'),
                                center: userPos,
                                radius: _radiusKm * 1000,
                                strokeWidth: 2,
                                strokeColor: AppColors.greenBrand.withAlpha(
                                  140,
                                ),
                                fillColor: AppColors.mint.withAlpha(18),
                              ),
                          },
                          mapType: _mapType,
                          style: _mapType == MapType.normal
                              ? mapStyleJson
                              : null,
                          zoomControlsEnabled: false,
                          mapToolbarEnabled: false,
                          myLocationEnabled: true,
                          myLocationButtonEnabled: false,
                          compassEnabled: false,
                          onCameraIdle: () => _recomputeMarkers(_lastReports),
                          onMapCreated: (c) {
                            _mapController = c;
                            WidgetsBinding.instance.addPostFrameCallback((
                              _,
                            ) async {
                              await Future<void>.delayed(
                                const Duration(milliseconds: 50),
                              );
                              if (!mounted) return;
                              // Con la posizione si inquadra il raggio
                              // di ricerca (anche tornando sulla tab),
                              // senza si inquadrano le segnalazioni.
                              if (_userPosition != null) {
                                await _fitRadius();
                              } else if (reports.isNotEmpty) {
                                await _fitReports(reports);
                              }
                              if (mounted && reports.isNotEmpty) {
                                await _recomputeMarkers(reports);
                              }
                            });
                          },
                        )
                      : const ColoredBox(color: AppColors.surfaceWarm),
                ),

                // Sfumatura crema sotto l'header: il titolo resta leggibile
                // sopra qualsiasi zona della mappa.
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: headerBottom + 40,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.3, 1],
                          colors: [
                            AppColors.bgAlt,
                            AppColors.bgAlt.withAlpha(0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  top: topInset + 12,
                  child: TabHeader(
                    title: 'Mappa',
                    actions: [
                      PointsPill(onTap: () => context.go(AppRoutes.classifica)),
                      const NotificationsBell(),
                    ],
                  ),
                ),

                // Livelli e "centra su di me", sul bordo destro sopra il
                // pannello.
                Positioned(
                  right: 16,
                  bottom: panelHeight + 12,
                  child: Column(
                    children: [
                      HeaderCircleButton(
                        icon: AppIcons.layers,
                        tooltip: _mapType == MapType.normal
                            ? 'Vista satellite'
                            : 'Vista mappa',
                        onPressed: _toggleMapType,
                      ),
                      const SizedBox(height: 10),
                      _resolvingGps
                          ? Container(
                              width: 48,
                              height: 48,
                              padding: const EdgeInsets.all(14),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const CircularProgressIndicator(
                                strokeWidth: 2.4,
                              ),
                            )
                          : HeaderCircleButton(
                              icon: AppIcons.myLocation,
                              tooltip: 'Centra sulla mia posizione',
                              onPressed: _goToCurrentGpsPosition,
                            ),
                    ],
                  ),
                ),

                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: panelHeight,
                  child: _ReportListPanel(
                    reports: reports,
                    title: userPos == null
                        ? 'Segnalazioni recenti'
                        : 'Vicino a te',
                    subtitle: subtitle,
                    emptyMessage: emptyMessage,
                    filters: _ReportFiltersBar(
                      radiusKm: _radiusKm,
                      radiusEnabled: userPos != null,
                      statusGroups: _statusGroups,
                      counts: isStreamLoading ? const {} : counts,
                      onRadiusChanged: _setRadius,
                      onStatusChanged: _setStatusGroups,
                    ),
                    toClean: isStreamLoading
                        ? 0
                        : counts[ReportStatusGroup.daPulire] ?? 0,
                    onReportTap: _openReportDetails,
                    userPosition: userPos,
                    isLoading: isStreamLoading,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ─── Pannello "Vicino a te" ─────────────────────────────────────────────────

class _ReportListPanel extends StatelessWidget {
  const _ReportListPanel({
    required this.reports,
    required this.title,
    required this.subtitle,
    required this.emptyMessage,
    required this.filters,
    required this.toClean,
    required this.onReportTap,
    this.userPosition,
    this.isLoading = false,
  });

  final List<TrashpotReport> reports;
  final String title;
  final String subtitle;
  final String emptyMessage;
  final Widget filters;

  /// Segnalazioni "da pulire" nella lista: se ce ne sono, in cima compare
  /// l'invito con i punti che valgono.
  final int toClean;
  final void Function(String reportId) onReportTap;
  final LatLng? userPosition;
  final bool isLoading;

  String? _distanceOf(TrashpotReport r) {
    final p = userPosition;
    if (p == null) return null;
    return distanceLabel(haversineKm(p.latitude, p.longitude, r.lat, r.lng));
  }

  void _showAllReports(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.greenLight,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 1,
        minChildSize: 0.5,
        maxChildSize: 1,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tutte le segnalazioni',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Chiudi',
                    icon: const Icon(AppIcons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: reports.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final r = reports[i];
                  return _ReportCard(
                    report: r,
                    distance: _distanceOf(r),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onReportTap(r.id);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.greenLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withAlpha(31),
            blurRadius: 28,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 22,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          height: 18 / 13,
                          color: context.palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (reports.isNotEmpty)
                  TextButton(
                    onPressed: () => _showAllReports(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.only(left: 12, right: 4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Vedi tutte'),
                        SizedBox(width: 2),
                        Icon(AppIcons.chevronRight, size: 18),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          filters,
          const SizedBox(height: 4),
          Expanded(
            child: isLoading
                ? const SkeletonList(
                    padding: EdgeInsets.fromLTRB(16, 10, 16, 96),
                  )
                : reports.isEmpty
                ? _EmptyList(message: emptyMessage)
                : ListView.separated(
                    // Spazio in fondo per il pulsante "Segnala".
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
                    itemCount: reports.length + (toClean > 0 ? 1 : 0),
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      if (toClean > 0 && i == 0) {
                        return _CleanupNudge(count: toClean);
                      }
                      final r = reports[i - (toClean > 0 ? 1 : 0)];
                      return _ReportCard(
                        report: r,
                        distance: _distanceOf(r),
                        onTap: () => onReportTap(r.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 96),
      children: [
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              AppIcons.place,
              size: 26,
              color: AppColors.greenBrand,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: context.palette.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// "5 punti da pulire qui vicino": ricorda quanto valgono le pulizie.
class _CleanupNudge extends StatelessWidget {
  const _CleanupNudge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final title = count == 1
        ? '1 punto da pulire qui vicino.'
        : '$count punti da pulire qui vicino.';
    return Semantics(
      label:
          '$title Ogni pulizia vale $pointsPerCleanup punti, '
          'in tutto ${count * pointsPerCleanup}.',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.forest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.yellow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                AppIcons.cleanFilled,
                size: 22,
                color: AppColors.onYellow,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 14,
                    height: 19 / 14,
                    color: Colors.white,
                  ),
                  children: [
                    TextSpan(
                      text: '$title\n',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const TextSpan(
                      text: 'Ogni pulizia vale $pointsPerCleanup punti.',
                      style: TextStyle(color: AppColors.mintText),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '+${count * pointsPerCleanup}',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                color: AppColors.yellow,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Filtri (raggio + stato) ────────────────────────────────────────────────

class _ReportFiltersBar extends StatelessWidget {
  const _ReportFiltersBar({
    required this.radiusKm,
    required this.radiusEnabled,
    required this.statusGroups,
    required this.counts,
    required this.onRadiusChanged,
    required this.onStatusChanged,
  });

  final int radiusKm;
  final bool radiusEnabled;
  final Set<ReportStatusGroup> statusGroups;

  /// Quante segnalazioni per gruppo: solo per i gruppi letti da Firestore
  /// (quelli esclusi dal filtro non si conoscono).
  final Map<ReportStatusGroup, int> counts;
  final ValueChanged<int> onRadiusChanged;
  final ValueChanged<Set<ReportStatusGroup>> onStatusChanged;

  bool get _all => statusGroups.length == ReportStatusGroup.values.length;

  /// Con "Tutti" attivo, toccare uno stato mostra solo quello; altrimenti
  /// lo aggiunge o lo toglie. Togliendo l'ultimo si torna a "Tutti".
  void _toggle(ReportStatusGroup group) {
    HapticFeedback.selectionClick();
    if (_all) {
      onStatusChanged({group});
      return;
    }
    final next = {...statusGroups};
    if (!next.remove(group)) next.add(group);
    onStatusChanged(next.isEmpty ? ReportStatusGroup.values.toSet() : next);
  }

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold<int>(0, (sum, n) => sum + n);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          PopupMenuButton<int>(
            enabled: radiusEnabled,
            tooltip: 'Raggio di ricerca',
            initialValue: radiusKm,
            onSelected: onRadiusChanged,
            itemBuilder: (_) => [
              for (final km in reportRadiusOptionsKm)
                CheckedPopupMenuItem(
                  value: km,
                  checked: km == radiusKm,
                  child: Text('Entro $km km'),
                ),
            ],
            // Il tap lo gestisce il PopupMenuButton, il chip è solo aspetto.
            child: IgnorePointer(
              child: _RadiusChip(
                label: radiusEnabled ? '$radiusKm km' : 'Raggio',
              ),
            ),
          ),
          Container(
            width: 1,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: AppColors.mintBorder,
          ),
          _FilterChip(
            label: 'Tutti',
            count: _all && counts.isNotEmpty ? total : null,
            selected: _all,
            selectedBg: AppColors.greenBrand,
            bg: Colors.white,
            fg: AppColors.greenDark,
            onTap: () {
              HapticFeedback.selectionClick();
              onStatusChanged(ReportStatusGroup.values.toSet());
            },
          ),
          for (final group in ReportStatusGroup.values) ...[
            const SizedBox(width: 8),
            _FilterChip(
              label: group.label,
              dot: _groupColor(group),
              count: counts[group],
              selected: !_all && statusGroups.contains(group),
              selectedBg: _groupColor(group),
              bg: _groupTint(group).bg,
              fg: _groupTint(group).fg,
              onTap: () => _toggle(group),
            ),
          ],
        ],
      ),
    );
  }
}

Color _groupColor(ReportStatusGroup group) => switch (group) {
  ReportStatusGroup.daPulire => AppColors.redPin,
  ReportStatusGroup.inCorso => AppColors.amberDot,
  ReportStatusGroup.evento => AppColors.bluePin,
  ReportStatusGroup.pulite => AppColors.greenPin,
};

({Color bg, Color fg}) _groupTint(ReportStatusGroup group) => switch (group) {
  ReportStatusGroup.daPulire => (bg: AppColors.redLight, fg: AppColors.redText),
  ReportStatusGroup.inCorso => (
    bg: AppColors.amberLight,
    fg: AppColors.amberText,
  ),
  ReportStatusGroup.evento => (bg: AppColors.blueLight, fg: AppColors.blueText),
  ReportStatusGroup.pulite => (
    bg: AppColors.greenStatusLight,
    fg: AppColors.greenStatusText,
  ),
};

class _RadiusChip extends StatelessWidget {
  const _RadiusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Raggio di ricerca: $label',
      excludeSemantics: true,
      child: Container(
        height: 40,
        padding: const EdgeInsets.only(left: 12, right: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppIcons.radius, size: 18, color: AppColors.greenDark),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.greenDark,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(AppIcons.dropdown, size: 16, color: AppColors.greenDark),
          ],
        ),
      ),
    );
  }
}

/// Chip di filtro: tinta tenue a riposo, colore pieno quando è selezionato.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.selectedBg,
    required this.bg,
    required this.fg,
    required this.onTap,
    this.count,
    this.dot,
  });

  final String label;
  final int? count;
  final Color? dot;
  final bool selected;
  final Color selectedBg;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = selected ? Colors.white : fg;
    return Semantics(
      button: true,
      selected: selected,
      label: count == null ? label : '$label, $count',
      excludeSemantics: true,
      child: Material(
        color: selected ? selectedBg : bg,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: AnimatedContainer(
            duration: MediaQuery.of(context).disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 150),
            height: 40,
            padding: EdgeInsets.only(left: dot == null ? 12 : 10, right: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dot != null) ...[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : dot,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: textColor.withAlpha(185),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Card segnalazione ──────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onTap, this.distance});

  final TrashpotReport report;
  final VoidCallback onTap;

  /// Distanza già formattata, es. "120 m" o "2,4 km".
  final String? distance;

  IconData get _statusIcon => switch (report.status) {
    TrashpotStatus.segnalata ||
    TrashpotStatus.aperta => AppIcons.forWasteType(report.typeLabel),
    TrashpotStatus.inLavorazione ||
    TrashpotStatus.puliziaInCorso => AppIcons.clean,
    TrashpotStatus.eventoCreato => AppIcons.calendar,
    TrashpotStatus.pulita || TrashpotStatus.ripulita => AppIcons.check,
    TrashpotStatus.sparita => AppIcons.hidden,
  };

  String get _statusText {
    final event = report.event;
    return switch (report.status) {
      TrashpotStatus.segnalata || TrashpotStatus.aperta => 'Da pulire',
      TrashpotStatus.inLavorazione => 'Presa in carico',
      TrashpotStatus.puliziaInCorso => 'Pulizia in corso',
      TrashpotStatus.eventoCreato =>
        event == null ? 'Evento' : 'Evento ${shortDayLabel(event.scheduledAt)}',
      TrashpotStatus.pulita || TrashpotStatus.ripulita => 'Pulita',
      TrashpotStatus.sparita => 'Sparita',
    };
  }

  String? get _meta {
    final created = report.createdAt;
    final parts = [
      if (report.typeLabel != null) report.typeLabel!,
      if (created != null) relativeTimeLabel(created),
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final (:bg, :fg) = AppColors.statusChip(report.status);
    final participants = report.event?.participants.length ?? 0;
    final meta = _meta;
    final (distValue, distUnit) = _splitDistance(distance);

    return Semantics(
      button: true,
      label: [
        report.title,
        _statusText,
        ?meta,
        if (distance != null) 'a $distance',
      ].join(', '),
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(color: AppColors.mintBorder, offset: Offset(0, 2)),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: report.photoUrl != null
                        ? Image(
                            image: CachedNetworkImageProvider(report.photoUrl!),
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _PlaceholderThumb(
                              bg: bg,
                              fg: fg,
                              icon: _statusIcon,
                            ),
                          )
                        : _PlaceholderThumb(bg: bg, fg: fg, icon: _statusIcon),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 20 / 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              height: 26,
                              padding: const EdgeInsets.only(
                                left: 7,
                                right: 10,
                              ),
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_statusIcon, size: 14, color: fg),
                                  const SizedBox(width: 5),
                                  Text(
                                    _statusText,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: fg,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (participants > 0)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    AppIcons.users,
                                    size: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$participants',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        if (meta != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                AppIcons.time,
                                size: 13,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  meta,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 16 / 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (distValue != null) ...[
                    const SizedBox(width: 10),
                    Container(
                      constraints: const BoxConstraints(minWidth: 56),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.yellowLight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            distValue,
                            style: const TextStyle(
                              fontSize: 22,
                              height: 24 / 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                              color: AppColors.yellowText,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          Text(
                            distUnit,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.yellowText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// "120 m" → ("120", "m"); "2,4 km" → ("2,4", "km").
  static (String?, String) _splitDistance(String? label) {
    if (label == null) return (null, '');
    final i = label.lastIndexOf(' ');
    if (i <= 0) return (label, '');
    return (label.substring(0, i), label.substring(i + 1));
  }
}

class _PlaceholderThumb extends StatelessWidget {
  const _PlaceholderThumb({
    required this.bg,
    required this.fg,
    required this.icon,
  });

  final Color bg;
  final Color fg;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      color: bg,
      child: Icon(icon, size: 28, color: fg),
    );
  }
}
