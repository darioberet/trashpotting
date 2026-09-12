import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../maps_android_init.dart';
import '../models/trashpot_report.dart';
import '../repositories/report_repository.dart';
import '../routes.dart';
import '../services/location_service.dart';
import '../theme/app_colors.dart';
import 'report_detail_screen.dart';

double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

String _distanceLabel(double km) {
  if (km < 1) return '${(km * 1000).round()} m';
  return '${km.toStringAsFixed(1)} km';
}

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

  double _markerHue(TrashpotStatus s) {
    return switch (s) {
      TrashpotStatus.aperta ||
      TrashpotStatus.segnalata => BitmapDescriptor.hueRed,
      TrashpotStatus.inLavorazione ||
      TrashpotStatus.puliziaInCorso => BitmapDescriptor.hueOrange,
      TrashpotStatus.eventoCreato => BitmapDescriptor.hueAzure,
      TrashpotStatus.pulita || TrashpotStatus.ripulita => BitmapDescriptor.hueGreen,
    };
  }

  Future<void> _openReportDetails(String reportId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReportDetailScreen(reportId: reportId),
      ),
    );
  }

  Future<void> _fitReports(Iterable<TrashpotReport> reports) async {
    final c = _mapController;
    if (c == null) return;
    final bounds = _boundsForReports(reports);
    if (bounds == null) return;
    try {
      await c.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    } catch (_) {}
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
      setState(() => _initialTarget ??= const LatLng(0, 0));
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('GPS non disponibile: $e')),
      );
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
                  color: AppColors.textSecondary,
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
      stream: _reportRepository.watchReports(),
      builder: (context, snapshot) {
        final rawReports = snapshot.data ?? const <TrashpotReport>[];
        final userPos = _userPosition;
        final reports = userPos == null
            ? rawReports
            : (List<TrashpotReport>.from(rawReports)
              ..sort((a, b) {
                final da = _haversineKm(
                    userPos.latitude, userPos.longitude, a.lat, a.lng);
                final db = _haversineKm(
                    userPos.latitude, userPos.longitude, b.lat, b.lng);
                return da.compareTo(db);
              }));
        final openCount = reports
            .where(
              (r) =>
                  r.status == TrashpotStatus.segnalata ||
                  r.status == TrashpotStatus.aperta,
            )
            .length;

        final markers = {
          for (final r in reports)
            Marker(
              markerId: MarkerId('tp_${r.id}'),
              position: LatLng(r.lat, r.lng),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                _markerHue(r.status),
              ),
              onTap: () => _openReportDetails(r.id),
              infoWindow: InfoWindow(
                title: r.title,
                snippet: trashpotStatusLabel(r.status),
              ),
            ),
        };

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
                                zoom: 13,
                              ),
                              markers: markers,
                              mapType: MapType.normal,
                              zoomControlsEnabled: false,
                              mapToolbarEnabled: false,
                              myLocationEnabled: true,
                              myLocationButtonEnabled: false,
                              compassEnabled: true,
                              onMapCreated: (c) {
                                _mapController = c;
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) async {
                                  await Future<void>.delayed(
                                    const Duration(milliseconds: 50),
                                  );
                                  if (mounted && reports.isNotEmpty) {
                                    await _fitReports(reports);
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
                        openCount: openCount,
                        onReportTap: _openReportDetails,
                        mapHeight: mapHeight,
                        userPosition: userPos,
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
                        : const Icon(Icons.my_location),
                  ),
                ),

                // ── Main FAB — navigate to Segnala ─────────────────────
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton(
                    heroTag: 'add_report',
                    onPressed: () => context.go(AppRoutes.segnala),
                    backgroundColor: AppColors.greenBrand,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: const CircleBorder(),
                    child: const Icon(Icons.add, size: 28),
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
    required this.openCount,
    required this.onReportTap,
    required this.mapHeight,
    this.userPosition,
  });

  final List<TrashpotReport> reports;
  final int openCount;
  final void Function(String reportId) onReportTap;
  final double mapHeight;
  final LatLng? userPosition;

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
                  color: AppColors.divider,
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
                    dist = _distanceLabel(_haversineKm(
                      userPosition!.latitude,
                      userPosition!.longitude,
                      r.lat,
                      r.lng,
                    ));
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

    return Transform.translate(
      offset: const Offset(0, -16),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vicino a te',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '$openCount segnalazioni aperte',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showAllReports(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
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

            // Report list
            Expanded(
              child: reports.isEmpty
                  ? Center(
                      child: Text(
                        'Nessuna segnalazione vicino a te.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                      itemCount: reports.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final r = reports[i];
                        String? dist;
                        if (userPosition != null) {
                          dist = _distanceLabel(_haversineKm(
                            userPosition!.latitude,
                            userPosition!.longitude,
                            r.lat,
                            r.lng,
                          ));
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceWarm,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: report.photoUrl != null
                  ? Image.network(
                      report.photoUrl!,
                      width: 56,
                      height: 56,
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
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
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
                          trashpotStatusLabel(report.status).toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
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
                        const Icon(Icons.place_outlined, size: 11, color: AppColors.textSecondary),
                        const SizedBox(width: 2),
                        Text(
                          computedDistanceLabel!,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (report.dateLabel != null) ...[
                        const Icon(Icons.access_time_outlined, size: 11, color: AppColors.textSecondary),
                        const SizedBox(width: 2),
                        Text(
                          report.dateLabel!,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (report.typeLabel != null)
                        Flexible(
                          child: Text(
                            report.typeLabel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
    );
  }
}

class _PlaceholderThumb extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      color: AppColors.divider,
      child: const Icon(Icons.image_outlined, size: 20, color: AppColors.textDisabled),
    );
  }
}
