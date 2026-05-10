import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../data/mock_trashpots.dart';
import '../models/trashpot_report.dart';

/// Mappa Google con marker per ogni trashpot (segnalazione).
///
/// Supportata su Android, iOS e web. Su desktop Windows/Linux/macOS native
/// il plugin non è disponibile: viene mostrato un messaggio esplicativo.
class MappaScreen extends StatefulWidget {
  const MappaScreen({super.key});

  @override
  State<MappaScreen> createState() => _MappaScreenState();
}

class _MappaScreenState extends State<MappaScreen> {
  GoogleMapController? _mapController;
  late final Set<Marker> _markers;

  /// Android [GoogleMap] uses a platform view that can call [RenderBox.localToGlobal]
  /// during a warm-up frame before the surrounding tree has finished layout,
  /// triggering `hasSize` assertions under [RenderFractionalTranslation].
  /// Mount the map only after at least one laid-out frame.
  bool _mapMountReady = false;

  static const _greenBrand = Color(0xFF1D9E75);

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

  LatLngBounds _boundsIncludingUser(Iterable<TrashpotReport> reports) {
    final pts = reports.map((r) => LatLng(r.lat, r.lng)).toList()
      ..add(const LatLng(kDemoUserLat, kDemoUserLng));
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
      TrashpotStatus.aperta || TrashpotStatus.segnalata => BitmapDescriptor.hueRed,
      TrashpotStatus.inLavorazione => BitmapDescriptor.hueOrange,
      TrashpotStatus.pulita => BitmapDescriptor.hueGreen,
    };
  }

  Future<void> _fitAll() async {
    final c = _mapController;
    if (c == null) return;
    await c.animateCamera(
      CameraUpdate.newLatLngBounds(
        _boundsIncludingUser(mockTrashpots),
        80,
      ),
    );
  }

  void _openTrashpotSheet(TrashpotReport r) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusChip(status: r.status, label: trashpotStatusLabel(r.status)),
                  const Spacer(),
                  if (r.distanceLabel != null)
                    Text(
                      r.distanceLabel!,
                      style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                r.title,
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.place_outlined, size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      r.address,
                      style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              if (r.typeLabel != null) ...[
                const SizedBox(height: 8),
                Text(
                  r.typeLabel!,
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
              if (r.dateLabel != null) ...[
                const SizedBox(height: 4),
                Text(
                  r.dateLabel!,
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    final deferMapMount =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    _mapMountReady = !deferMapMount;
    if (deferMapMount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _mapMountReady = true);
        });
      });
    }
    final trashpots = mockTrashpots;
    _markers = {
      Marker(
        markerId: const MarkerId('user_demo'),
        position: const LatLng(kDemoUserLat, kDemoUserLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'La tua posizione (demo)'),
      ),
      for (final r in trashpots)
        Marker(
          markerId: MarkerId('tp_${r.id}'),
          position: LatLng(r.lat, r.lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(_markerHue(r.status)),
          onTap: () => _openTrashpotSheet(r),
          infoWindow: InfoWindow(title: r.title, snippet: trashpotStatusLabel(r.status)),
        ),
    };
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
              Icon(Icons.map_outlined, size: 64, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Google Maps è disponibile su Android, iOS e web.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Esegui l’app su emulatore/dispositivo o Chrome per vedere la mappa.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    final initialBounds = _boundsIncludingUser(mockTrashpots);
    final initialTarget = LatLng(
      (initialBounds.northeast.latitude + initialBounds.southwest.latitude) / 2,
      (initialBounds.northeast.longitude + initialBounds.southwest.longitude) / 2,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: _mapMountReady
              ? GoogleMap(
                  initialCameraPosition:
                      CameraPosition(target: initialTarget, zoom: 13),
                  markers: _markers,
                  mapType: MapType.normal,
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  compassEnabled: true,
                  onMapCreated: (c) {
                    _mapController = c;
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      await Future<void>.delayed(
                        const Duration(milliseconds: 50),
                      );
                      if (mounted) await _fitAll();
                    });
                  },
                )
              : ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: FloatingActionButton.small(
            heroTag: 'recenter_map',
            onPressed: _fitAll,
            tooltip: 'Mostra tutti i punti',
            backgroundColor: _greenBrand,
            foregroundColor: Colors.white,
            child: const Icon(Icons.fit_screen),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.label});

  final TrashpotStatus status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    switch (status) {
      case TrashpotStatus.aperta:
      case TrashpotStatus.segnalata:
        bg = const Color(0xFFFCEBEB);
        fg = const Color(0xFF791F1F);
      case TrashpotStatus.inLavorazione:
        bg = const Color(0xFFFAEEDA);
        fg = const Color(0xFF633806);
      case TrashpotStatus.pulita:
        bg = const Color(0xFFE1F5EE);
        fg = const Color(0xFF085041);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}
