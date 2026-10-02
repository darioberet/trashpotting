import 'dart:async';
import 'dart:io';

import 'package:geocoding/geocoding.dart' as geo;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

import '../core/geo_utils.dart';
import '../models/trashpot_report.dart';
import '../repositories/report_repository.dart';
import '../routes.dart';
import '../services/location_service.dart';
import '../services/media_picker_service.dart';
import '../services/report_service.dart';
import '../services/image_processing_service.dart';
import '../state/app_session.dart';
import '../state/segnala_view_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../widgets/image_source_bottom_sheet.dart';

class SegnalaScreen extends StatefulWidget {
  SegnalaScreen({
    super.key,
    ReportService? reportService,
    MediaPickerService? mediaPickerService,
    LocationService? locationService,
    ImageProcessingService? imageProcessingService,
    ReportRepository? reportRepository,
  }) : _reportRepository = reportRepository ?? FirestoreReportRepository(),
       _reportService = reportService ?? ReportService(),
       _mediaPickerService = mediaPickerService ?? MediaPickerService(),
       _locationService = locationService ?? LocationService(),
       _imageProcessingService =
           imageProcessingService ?? const ImageProcessingService();

  final ReportRepository _reportRepository;
  final ReportService _reportService;
  final MediaPickerService _mediaPickerService;
  final LocationService _locationService;
  final ImageProcessingService _imageProcessingService;

  @override
  State<SegnalaScreen> createState() => _SegnalaScreenState();
}

class _SegnalaScreenState extends State<SegnalaScreen> {
  final _note = TextEditingController();
  late final SegnalaViewModel _viewModel;
  int _seenInfoToken = 0;
  int _seenErrorToken = 0;
  bool _resolvingPosition = false;

  @override
  void initState() {
    super.initState();
    _viewModel = SegnalaViewModel(reportService: widget._reportService);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_resolvePosition(silent: true));
    });
  }

  /// Avvisa se entro [duplicateRadiusMeters] c'è già una segnalazione attiva.
  /// Restituisce true se si può procedere con l'invio.
  Future<bool> _confirmNotDuplicate() async {
    final lat = _viewModel.latitude;
    final lng = _viewModel.longitude;
    if (lat == null || lng == null) return true;

    List<TrashpotReport> nearby;
    try {
      nearby = await widget._reportRepository.findActiveNearby(
        latitude: lat,
        longitude: lng,
      );
    } catch (_) {
      return true; // il controllo è un aiuto, non deve bloccare l'invio
    }
    if (nearby.isEmpty || !mounted) return true;

    final closest = nearby.reduce(
      (a, b) =>
          haversineKm(lat, lng, a.lat, a.lng) <=
              haversineKm(lat, lng, b.lat, b.lng)
          ? a
          : b,
    );
    final meters = (haversineKm(lat, lng, closest.lat, closest.lng) * 1000)
        .round();

    final choice = await showDialog<_DuplicateChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Forse è già stato segnalato'),
        content: Text(
          'A $meters m da qui c\'è già una segnalazione ancora da pulire:\n\n'
          '«${closest.title}»'
          '${nearby.length > 1 ? '\n\n(e altre ${nearby.length - 1} vicine)' : ''}'
          '\n\nSe è lo stesso rifiuto, aprila invece di crearne una nuova.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_DuplicateChoice.sendAnyway),
            child: const Text('È un altro, invia'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(_DuplicateChoice.open),
            child: const Text('Apri quella'),
          ),
        ],
      ),
    );
    if (!mounted) return false;
    if (choice == _DuplicateChoice.open) {
      context.push('${AppRoutes.reportDetail}/${closest.id}');
      return false;
    }
    return choice == _DuplicateChoice.sendAnyway;
  }

  Future<void> _send() async {
    if (_viewModel.sending) return;
    final session = AppSessionScope.of(context);

    final hasLocation = await _resolvePosition(forceRefresh: true);
    if (!hasLocation || !mounted) return;

    if (!await _confirmNotDuplicate() || !mounted) return;

    await _viewModel.submit(
      firebaseReady: session.firebaseReady,
      note: _note.text,
      uid: session.currentUserId,
      username: session.username,
    );

    if (!mounted) return;

    if (_viewModel.infoToken > _seenInfoToken && _viewModel.lastInfo != null) {
      _seenInfoToken = _viewModel.infoToken;
      session.publishInfo(_viewModel.lastInfo!);
      if (_viewModel.lastInfo == 'Segnalazione inviata correttamente.') {
        _note.clear();
        _viewModel.clearDraftExtras();
      }
    }
    if (_viewModel.errorToken > _seenErrorToken &&
        _viewModel.lastError != null) {
      _seenErrorToken = _viewModel.errorToken;
      session.publishError(
        _viewModel.lastError!,
        fallback: _viewModel.lastErrorFallback,
      );
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final session = AppSessionScope.of(context);
    try {
      final path = await widget._mediaPickerService.pickImagePath(source);
      if (!mounted || path == null) return;
      _viewModel.setPhotoPath(path);
      session.publishInfo('Foto allegata alla segnalazione.');

      if (kDebugMode) {
        final estimatedBytes = await widget._imageProcessingService
            .estimateCompressedSizeBytes(path);
        if (!mounted || estimatedBytes == null) return;
        final kb = estimatedBytes / 1024;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('DEBUG — stima: ${kb.toStringAsFixed(1)} KB'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      session.publishError(e, fallback: 'Impossibile selezionare la foto.');
    }
  }

  Future<void> _choosePhotoSource() async {
    final source = await showImageSourceBottomSheet(context);
    if (source != null) await _pickPhoto(source);
  }

  Future<bool> _resolvePosition({
    bool silent = false,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _viewModel.latitude != null &&
        _viewModel.longitude != null) {
      return true;
    }
    if (_resolvingPosition) return true;
    final session = AppSessionScope.of(context);
    setState(() => _resolvingPosition = true);
    try {
      final p = await widget._locationService.getCurrentPosition();
      if (!mounted) return false;
      String? resolvedAddress;
      try {
        final placemarks = await geo.placemarkFromCoordinates(
          p.latitude,
          p.longitude,
        );
        if (placemarks.isNotEmpty) {
          final pm = placemarks.first;
          final parts = [
            if ((pm.street ?? '').isNotEmpty) pm.street,
            if ((pm.locality ?? '').isNotEmpty) pm.locality,
          ];
          if (parts.isNotEmpty) resolvedAddress = parts.join(', ');
        }
      } catch (_) {}
      _viewModel.setLocation(
        latitude: p.latitude,
        longitude: p.longitude,
        address: resolvedAddress,
        accuracy: p.accuracy,
      );
      if (!silent) session.publishInfo('Posizione GPS acquisita.');
      return true;
    } catch (e) {
      if (!mounted) return false;
      session.publishError(
        e,
        fallback: 'Impossibile ottenere la posizione attuale del dispositivo.',
      );
      return false;
    } finally {
      if (mounted) setState(() => _resolvingPosition = false);
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: AbsorbPointer(
                      absorbing: _viewModel.sending,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        children: [
                          Text(
                            'Segnala rifiuti',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 22,
                                  color: context.palette.textPrimary,
                                ),
                          ),
                          const SizedBox(height: 16),
                          _PhotoUploadArea(
                            photoPath: _viewModel.photoPath,
                            onTap: _choosePhotoSource,
                            onRemove: _viewModel.clearPhoto,
                          ),
                          const SizedBox(height: 12),
                          _GpsChip(
                            resolving: _resolvingPosition,
                            latitude: _viewModel.latitude,
                            longitude: _viewModel.longitude,
                            address: _viewModel.address,
                            accuracy: _viewModel.accuracy,
                            onRefresh: () =>
                                _resolvePosition(forceRefresh: true),
                          ),
                          const SizedBox(height: 16),
                          _FieldLabel('Tipo di rifiuto'),
                          const SizedBox(height: 8),
                          _TypeSelector(
                            selected: _viewModel.reportType,
                            onSelected: _viewModel.setReportType,
                          ),
                          const SizedBox(height: 16),
                          _FieldLabel('Descrizione'),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _note,
                            maxLines: 4,
                            maxLength: 300,
                            decoration: const InputDecoration(
                              hintText:
                                  'Descrivi brevemente i rifiuti che hai trovato...',
                              alignLabelWithHint: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Sticky bottom CTA
                  _StickyBottomBar(sending: _viewModel.sending, onSend: _send),
                ],
              ),

              if (_viewModel.sending)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black26,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Sub-widgets ────────────────────────────────────────────────────────────

class _PhotoUploadArea extends StatelessWidget {
  const _PhotoUploadArea({
    required this.photoPath,
    required this.onTap,
    required this.onRemove,
  });

  final String? photoPath;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoPath != null;

    if (hasPhoto) {
      return Semantics(
        label: 'Foto allegata. Tocca per cambiare.',
        button: true,
        child: Stack(
          children: [
            GestureDetector(
              onTap: onTap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    kIsWeb
                        ? Container(
                            height: 180,
                            width: double.infinity,
                            color: context.palette.surfaceWarm,
                            alignment: Alignment.center,
                            child: Text(
                              photoPath!.split(RegExp(r'[\\/]')).last,
                              style: TextStyle(
                                fontSize: 13,
                                color: context.palette.textSecondary,
                              ),
                            ),
                          )
                        : Image.file(
                            File(photoPath!),
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      color: Colors.black.withAlpha(140),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.image_outlined,
                            size: 16,
                            color: Colors.white,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Tocca per cambiare foto',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Semantics(
                label: 'Rimuovi foto',
                button: true,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(140),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Semantics(
      label: 'Tocca per aggiungere una foto',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            color: context.palette.surfaceWarm,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.palette.divider,
              width: 1.5,
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/icons/camera.svg',
                width: 38,
                height: 38,
                colorFilter: const ColorFilter.mode(
                  AppColors.greenBrand,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Scatta o scegli una foto',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.palette.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'La foto aiuta la verifica.\n'
                'Inquadra solo i rifiuti: niente volti né targhe.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: context.palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GpsChip extends StatelessWidget {
  const _GpsChip({
    required this.resolving,
    required this.latitude,
    required this.longitude,
    this.address,
    this.accuracy,
    this.onRefresh,
  });

  final bool resolving;
  final double? latitude;
  final double? longitude;
  final String? address;
  final double? accuracy;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    if (resolving) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: context.palette.surfaceWarm,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppColors.greenBrand,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Recupero posizione...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: context.palette.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (latitude == null || longitude == null) return const SizedBox.shrink();

    final subtitle = accuracy != null
        ? 'GPS · precisione ±${accuracy!.round()}m'
        : 'GPS';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.palette.greenLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/icons/location_pin.svg',
            width: 20,
            height: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  address ??
                      'Lat ${latitude!.toStringAsFixed(5)}, Lng ${longitude!.toStringAsFixed(5)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.palette.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (onRefresh != null) ...[
            const SizedBox(width: 8),
            Semantics(
              label: 'Aggiorna posizione GPS',
              button: true,
              child: InkWell(
                onTap: onRefresh,
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: SvgPicture.asset(
                    'assets/icons/gps_target.svg',
                    width: 22,
                    height: 22,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StickyBottomBar extends StatelessWidget {
  const _StickyBottomBar({required this.sending, required this.onSend});

  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: context.palette.divider, width: 0.5),
        ),
      ),
      child: FilledButton.icon(
        onPressed: sending ? null : onSend,
        icon: sending
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.send_outlined, size: 18),
        label: Text(sending ? 'Invio in corso...' : 'Invia segnalazione'),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: context.palette.textPrimary,
      ),
    );
  }
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.selected, required this.onSelected});

  final String? selected;
  final void Function(String?) onSelected;

  static const _types = [
    'Discarica abusiva',
    'Rifiuti abbandonati',
    'Rifiuti pericolosi',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.palette.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: context.palette.cardShadow,
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, t) in _types.indexed) ...[
            if (i > 0) Divider(height: 1, color: context.palette.divider),
            InkWell(
              onTap: () => onSelected(selected == t ? null : t),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      selected == t
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      size: 18,
                      color: selected == t
                          ? AppColors.greenBrand
                          : context.palette.textDisabled,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      t,
                      style: TextStyle(
                        fontSize: 13,
                        color: selected == t
                            ? context.palette.textPrimary
                            : context.palette.textSecondary,
                        fontWeight: selected == t
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _DuplicateChoice { open, sendAnyway }
