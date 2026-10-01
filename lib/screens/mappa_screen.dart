import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/geo_utils.dart';
import '../core/map_style.dart';
import '../core/marker_clustering.dart';
import '../core/marker_icons.dart';
import '../maps_android_init.dart';
import '../models/report_filter.dart';
import '../models/trashpot_report.dart';
import '../repositories/report_repository.dart';
import '../routes.dart';
import '../services/location_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';

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
  static const _statusPrefsKey = 'map_status_groups';
  final _preferences = SharedPreferencesAsync();
  int _radiusKm = defaultReportRadiusKm;
  Set<ReportStatusGroup> _statusGroups = {...defaultReportStatusGroups};

  // Lo stream va memorizzato: ricrearlo a ogni build (es. dopo il
  // setState del clustering) riaprirebbe tutte le query Firestore.
  Stream<List<TrashpotReport>>? _reportsStream;
  String? _reportsStreamKey;

  Stream<List<TrashpotReport>> _reportsStreamFor(LatLng? center) {
    final key = center == null
        ? 'recent'
        : '${center.latitude},${center.longitude},$_radiusKm';
    if (key != _reportsStreamKey || _reportsStream == null) {
      _reportsStreamKey = key;
      _reportsStream = center == null
          ? _reportRepository.watchReports()
          : _reportRepository.watchReportsNear(
              latitude: center.latitude,
              longitude: center.longitude,
              radiusKm: _radiusKm.toDouble(),
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

  void _toggleStatusGroup(ReportStatusGroup group) {
    setState(() {
      _statusGroups = {..._statusGroups};
      if (!_statusGroups.remove(group)) _statusGroups.add(group);
    });
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

  Color _markerColor(TrashpotStatus s) {
    return switch (s) {
      TrashpotStatus.segnalata => AppColors.redPin,
      TrashpotStatus.aperta => AppColors.amberDot,
      TrashpotStatus.inLavorazione ||
      TrashpotStatus.puliziaInCorso => context.palette.textSecondary,
      TrashpotStatus.eventoCreato => AppColors.blueText,
      TrashpotStatus.pulita || TrashpotStatus.ripulita => AppColors.greenBrand,
    };
  }

  IconData _markerIcon(TrashpotStatus s) {
    return switch (s) {
      TrashpotStatus.segnalata => Icons.warning_amber_outlined,
      TrashpotStatus.aperta => Icons.schedule_outlined,
      TrashpotStatus.inLavorazione ||
      TrashpotStatus.puliziaInCorso => Icons.build_outlined,
      TrashpotStatus.eventoCreato => Icons.event_outlined,
      TrashpotStatus.pulita ||
      TrashpotStatus.ripulita => Icons.check_circle_outline,
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
        final icon = await MarkerIconFactory.cluster(count: group.items.length);
        if (!mounted || epoch != _clusterEpoch) return;
        markers.add(
          Marker(
            markerId: MarkerId(
              'cluster_${group.center.latitude}_${group.center.longitude}_${group.items.length}',
            ),
            position: group.center,
            icon: icon,
            onTap: () => _fitReports(group.items),
          ),
        );
      } else {
        final r = group.items.first;
        final icon = await MarkerIconFactory.pin(
          color: _markerColor(r.status),
          icon: _markerIcon(r.status),
        );
        if (!mounted || epoch != _clusterEpoch) return;
        markers.add(
          Marker(
            markerId: MarkerId('tp_${r.id}'),
            position: LatLng(r.lat, r.lng),
            icon: icon,
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
    if (!_googleMapsAvailable) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, size: 64, color: AppColors.greenBrand),
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
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Errore di rete. Riavvia l\'app o verifica la connessione.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
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
        final countLabel = reports.length == 1
            ? '1 segnalazione'
            : '${reports.length} segnalazioni';
        final subtitle = userPos == null
            ? '$countLabel recenti · posizione non disponibile'
            : '$countLabel entro $_radiusKm km';
        final allStatuses =
            _statusGroups.length == ReportStatusGroup.values.length;
        final emptyMessage = _statusGroups.isEmpty
            ? 'Seleziona almeno uno stato.'
            : userPos == null
            ? 'Nessuna segnalazione con questi filtri.'
            : allStatuses
            ? 'Nessuna segnalazione entro $_radiusKm km.\n'
                  'Prova ad allargare il raggio.'
            : 'Nessuna segnalazione entro $_radiusKm km con questi filtri.\n'
                  'Prova ad allargare il raggio o a includere altri stati.';

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
            final mapHeight = constraints.maxHeight * 0.46;

            return Stack(
              children: [
                // ── Map + bottom panel column ──────────────────────────
                Column(
                  children: [
                    SizedBox(
                      height: mapHeight,
                      child: _mapMountReady
                          ? GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: _initialTarget!,
                                zoom: _userPosition == null ? 5.5 : 13,
                              ),
                              markers: _displayMarkers,
                              circles: {
                                if (userPos != null)
                                  Circle(
                                    circleId: const CircleId('search_radius'),
                                    center: userPos,
                                    radius: _radiusKm * 1000,
                                    strokeWidth: 1,
                                    strokeColor: AppColors.greenBrand.withAlpha(
                                      160,
                                    ),
                                    fillColor: AppColors.greenBrand.withAlpha(
                                      18,
                                    ),
                                  ),
                              },
                              mapType: MapType.normal,
                              style: mapStyleJson,
                              zoomControlsEnabled: false,
                              mapToolbarEnabled: false,
                              myLocationEnabled: true,
                              myLocationButtonEnabled: false,
                              compassEnabled: true,
                              onCameraIdle: () =>
                                  _recomputeMarkers(_lastReports),
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
                          : ColoredBox(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                            ),
                    ),
                    Expanded(
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
                          onRadiusChanged: _setRadius,
                          onStatusToggled: _toggleStatusGroup,
                        ),
                        onReportTap: _openReportDetails,
                        userPosition: userPos,
                        isLoading: isStreamLoading,
                      ),
                    ),
                  ],
                ),

                // ── Recenter FAB (inside map, bottom-right of map area) ─
                Positioned(
                  right: 12,
                  top: mapHeight - 48 - 12,
                  child: FloatingActionButton.small(
                    heroTag: 'recenter_map',
                    onPressed: _resolvingGps ? null : _goToCurrentGpsPosition,
                    tooltip: 'Vai alla tua posizione GPS',
                    backgroundColor: AppColors.greenBrand,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    child: _resolvingGps
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : SvgPicture.asset(
                            'assets/icons/gps_target.svg',
                            width: 20,
                            height: 20,
                            colorFilter: const ColorFilter.mode(
                              Colors.white,
                              BlendMode.srcIn,
                            ),
                          ),
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

// ─── Bottom panel with report list ──────────────────────────────────────────

class _ReportListPanel extends StatelessWidget {
  const _ReportListPanel({
    required this.reports,
    required this.title,
    required this.subtitle,
    required this.emptyMessage,
    required this.filters,
    required this.onReportTap,
    this.userPosition,
    this.isLoading = false,
  });

  final List<TrashpotReport> reports;
  final String title;
  final String subtitle;
  final String emptyMessage;
  final Widget filters;
  final void Function(String reportId) onReportTap;
  final LatLng? userPosition;
  final bool isLoading;

  void _showAllReports(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 1,
        minChildSize: 0.5,
        maxChildSize: 1,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.palette.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Tutte le segnalazioni',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: reports.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final r = reports[i];
                  String? dist;
                  if (userPosition != null) {
                    dist = distanceLabel(
                      haversineKm(
                        userPosition!.latitude,
                        userPosition!.longitude,
                        r.lat,
                        r.lng,
                      ),
                    );
                  }
                  return _ReportCard(
                    report: r,
                    computedDistanceLabel: dist,
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
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(color: context.palette.divider, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.palette.textPrimary,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: context.palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _showAllReports(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    minimumSize: const Size(48, 48),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    children: [
                      const Text('Vedi tutte', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: AppColors.greenBrand,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          filters,
          const SizedBox(height: 8),

          // Report list
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : reports.isEmpty
                ? Center(
                    child: Text(
                      emptyMessage,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    itemCount: reports.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final r = reports[i];
                      String? dist;
                      if (userPosition != null) {
                        dist = distanceLabel(
                          haversineKm(
                            userPosition!.latitude,
                            userPosition!.longitude,
                            r.lat,
                            r.lng,
                          ),
                        );
                      }
                      return _ReportCard(
                        report: r,
                        computedDistanceLabel: dist,
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

// ─── Filters (raggio + stato) ───────────────────────────────────────────────

class _ReportFiltersBar extends StatelessWidget {
  const _ReportFiltersBar({
    required this.radiusKm,
    required this.radiusEnabled,
    required this.statusGroups,
    required this.onRadiusChanged,
    required this.onStatusToggled,
  });

  final int radiusKm;
  final bool radiusEnabled;
  final Set<ReportStatusGroup> statusGroups;
  final ValueChanged<int> onRadiusChanged;
  final ValueChanged<ReportStatusGroup> onStatusToggled;

  @override
  Widget build(BuildContext context) {
    // Colori espliciti: il chipTheme globale non ha bordo né colore del
    // testo, e i chip non selezionati sparirebbero sul pannello bianco.
    final cs = Theme.of(context).colorScheme;
    final side = BorderSide(color: cs.outline);
    final labelStyle = TextStyle(color: cs.onSurface);

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
              child: Chip(
                avatar: Icon(Icons.radar, size: 16, color: cs.primary),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(radiusEnabled ? 'Entro $radiusKm km' : 'Raggio'),
                    Icon(Icons.arrow_drop_down, size: 18, color: cs.onSurface),
                  ],
                ),
                labelStyle: labelStyle,
                backgroundColor: cs.surfaceContainerHighest,
                side: side,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          const SizedBox(width: 8),
          for (final group in ReportStatusGroup.values) ...[
            FilterChip(
              label: Text(group.label),
              selected: statusGroups.contains(group),
              onSelected: (_) => onStatusToggled(group),
              labelStyle: statusGroups.contains(group)
                  ? TextStyle(color: cs.onPrimary)
                  : labelStyle,
              backgroundColor: cs.surface,
              selectedColor: cs.primary,
              checkmarkColor: cs.onPrimary,
              side: statusGroups.contains(group)
                  ? BorderSide(color: cs.primary)
                  : side,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

// ─── Report card ────────────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.onTap,
    this.computedDistanceLabel,
  });

  final TrashpotReport report;
  final VoidCallback onTap;
  final String? computedDistanceLabel;

  @override
  Widget build(BuildContext context) {
    final (:bg, :fg) = AppColors.statusChip(report.status);

    return Semantics(
      label: '${report.title}, ${trashpotStatusLabel(report.status)}',
      button: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Material(
          color: context.palette.surfaceWarm,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Status accent bar
                  Container(
                    width: 3,
                    height: 64,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: fg,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: report.photoUrl != null
                        ? Image.network(
                            report.photoUrl!,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _PlaceholderThumb(),
                          )
                        : _PlaceholderThumb(),
                  ),
                  const SizedBox(width: 12),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                report.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: context.palette.textPrimary,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                trashpotStatusLabel(
                                  report.status,
                                ).toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: fg,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            if (computedDistanceLabel != null) ...[
                              Icon(
                                Icons.place_outlined,
                                size: 11,
                                color: context.palette.textSecondary,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                computedDistanceLabel!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.palette.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            if (report.dateLabel != null) ...[
                              Icon(
                                Icons.access_time_outlined,
                                size: 11,
                                color: context.palette.textSecondary,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                report.dateLabel!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.palette.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            if (report.typeLabel != null)
                              Flexible(
                                child: Text(
                                  report.typeLabel!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.palette.textSecondary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
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

class _PlaceholderThumb extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      color: context.palette.greenLight,
      child: const Icon(
        Icons.terrain_outlined,
        size: 22,
        color: AppColors.greenBrand,
      ),
    );
  }
}
