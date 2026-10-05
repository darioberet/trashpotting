import 'dart:async';
import 'dart:io';

import 'package:geocoding/geocoding.dart' as geo;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

import '../core/geo_utils.dart';
import '../models/trashpot_report.dart';
import '../repositories/leaderboard_repository.dart' show pointsPerReport;
import '../repositories/report_repository.dart';
import '../routes.dart';
import '../services/location_service.dart';
import '../services/media_picker_service.dart';
import '../services/report_service.dart';
import '../services/image_processing_service.dart';
import '../state/app_session.dart';
import '../state/segnala_view_model.dart';
import '../theme/app_colors.dart';
import '../widgets/app_button.dart';
import '../widgets/image_source_bottom_sheet.dart';
import '../widgets/tab_header.dart';
import '../theme/app_icons.dart';

/// Segnala a tutto schermo, aperta dal pulsante giallo della Mappa (e dagli
/// inviti "Fai la prima segnalazione"). Dopo l'invio torna indietro.
class SegnalaPage extends StatelessWidget {
  const SegnalaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: SegnalaScreen(
          onSubmitted: () {
            if (context.canPop()) context.pop();
          },
        ),
      ),
    );
  }
}

class SegnalaScreen extends StatefulWidget {
  SegnalaScreen({
    super.key,
    this.onSubmitted,
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

  /// Chiamata dopo un invio riuscito.
  final VoidCallback? onSubmitted;

  @override
  State<SegnalaScreen> createState() => _SegnalaScreenState();
}

class _SegnalaScreenState extends State<SegnalaScreen> {
  final _note = TextEditingController();
  late final SegnalaViewModel _viewModel;
  int _seenInfoToken = 0;
  int _seenErrorToken = 0;
  bool _resolvingPosition = false;
  bool _showNote = false;

  /// Segnalazione attiva più vicina, se ce n'è una entro
  /// [duplicateRadiusMeters] dalla posizione attuale.
  ({TrashpotReport report, int meters})? _nearbyNotice;

  Future<void> _loadNearby(double lat, double lng) async {
    try {
      final nearby = await widget._reportRepository.findActiveNearby(
        latitude: lat,
        longitude: lng,
      );
      if (!mounted) return;
      if (nearby.isEmpty) {
        setState(() => _nearbyNotice = null);
        return;
      }
      final closest = nearby.reduce(
        (a, b) =>
            haversineKm(lat, lng, a.lat, a.lng) <=
                haversineKm(lat, lng, b.lat, b.lng)
            ? a
            : b,
      );
      setState(
        () => _nearbyNotice = (
          report: closest,
          meters: (haversineKm(lat, lng, closest.lat, closest.lng) * 1000)
              .round(),
        ),
      );
    } catch (_) {
      // È solo un aiuto: senza, al momento dell'invio c'è comunque il dialog.
    }
  }

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
    // L'avviso è già nella pagina: chi invia lo ha visto.
    if (_nearbyNotice != null) return true;

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
        unawaited(HapticFeedback.mediumImpact());
        _note.clear();
        _showNote = false;
        _viewModel.clearDraftExtras();
        widget.onSubmitted?.call();
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
      unawaited(_loadNearby(p.latitude, p.longitude));
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
        final steps = (
          photo: _viewModel.photoPath != null,
          position: _viewModel.latitude != null && _viewModel.longitude != null,
          type: _viewModel.reportType != null,
        );
        final ready = [
          steps.photo,
          steps.position,
          steps.type,
        ].where((s) => s).length;
        final nearby = _nearbyNotice;

        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              Column(
                children: [
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 56,
                            child: Row(
                              children: [
                                HeaderCircleButton(
                                  icon: AppIcons.close,
                                  tooltip: 'Chiudi',
                                  onPressed: () =>
                                      Navigator.of(context).maybePop(),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Semantics(
                                    header: true,
                                    child: const Text(
                                      'Segnala',
                                      style: TextStyle(
                                        fontSize: 26,
                                        height: 32 / 26,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.8,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.greenLight,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '$ready di 3 pronti',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.greenDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _StepBar(
                                  label: 'Foto',
                                  done: steps.photo,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _StepBar(
                                  label: 'Posizione',
                                  done: steps.position,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _StepBar(
                                  label: 'Tipo',
                                  done: steps.type,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: AbsorbPointer(
                      absorbing: _viewModel.sending,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        children: [
                          _PhotoUploadArea(
                            photoPath: _viewModel.photoPath,
                            onTap: _choosePhotoSource,
                          ),
                          const SizedBox(height: 14),
                          _GpsCard(
                            resolving: _resolvingPosition,
                            latitude: _viewModel.latitude,
                            longitude: _viewModel.longitude,
                            address: _viewModel.address,
                            accuracy: _viewModel.accuracy,
                            onRefresh: () =>
                                _resolvePosition(forceRefresh: true),
                          ),
                          if (nearby != null) ...[
                            const SizedBox(height: 14),
                            _NearbyNotice(
                              meters: nearby.meters,
                              onOpen: () => context.push(
                                '${AppRoutes.reportDetail}/${nearby.report.id}',
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          Semantics(
                            header: true,
                            child: const Text(
                              'Che rifiuti hai trovato?',
                              style: TextStyle(
                                fontSize: 17,
                                height: 22 / 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          _TypeSelector(
                            selected: _viewModel.reportType,
                            onSelected: _viewModel.setReportType,
                          ),
                          const SizedBox(height: 18),
                          if (_showNote || _note.text.isNotEmpty)
                            TextField(
                              controller: _note,
                              autofocus: _note.text.isEmpty,
                              maxLines: 4,
                              minLines: 2,
                              maxLength: 300,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                labelText: 'Descrizione (facoltativa)',
                                hintText:
                                    'Es. sacchi neri a bordo strada, '
                                    'vicino al parcheggio',
                                alignLabelWithHint: true,
                              ),
                            )
                          else
                            _AddNoteButton(
                              onTap: () => setState(() => _showNote = true),
                            ),
                        ],
                      ),
                    ),
                  ),
                  _StickyBottomBar(sending: _viewModel.sending, onSend: _send),
                ],
              ),
              if (_viewModel.sending)
                const Positioned.fill(child: ColoredBox(color: Colors.black12)),
            ],
          ),
        );
      },
    );
  }
}

// ─── Sub-widgets ────────────────────────────────────────────────────────────

/// Un passo della barra in alto: segmento verde e spunta quando è fatto.
class _StepBar extends StatelessWidget {
  const _StepBar({required this.label, required this.done});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: ${done ? 'fatto' : 'da fare'}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 6,
            decoration: BoxDecoration(
              color: done ? AppColors.greenBrand : AppColors.mintBorder,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (done) ...[
                const Icon(
                  AppIcons.check,
                  size: 13,
                  color: AppColors.greenDark,
                ),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: done ? AppColors.greenDark : AppColors.textDisabled,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhotoUploadArea extends StatelessWidget {
  const _PhotoUploadArea({required this.photoPath, required this.onTap});

  final String? photoPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final path = photoPath;
    if (path != null) {
      return Semantics(
        label: 'Foto allegata',
        image: true,
        child: SizedBox(
          height: 172,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                kIsWeb
                    ? ColoredBox(
                        color: AppColors.surfaceWarm,
                        child: Center(
                          child: Text(
                            path.split(RegExp(r'[\\/]')).last,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    : Image.file(File(path), fit: BoxFit.cover),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Material(
                    color: Colors.white,
                    shape: const StadiumBorder(),
                    elevation: 3,
                    shadowColor: AppColors.textPrimary.withAlpha(80),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: onTap,
                      child: const SizedBox(
                        height: 40,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                AppIcons.camera,
                                size: 18,
                                color: AppColors.textPrimary,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Cambia foto',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Semantics(
      label: 'Aggiungi una foto dei rifiuti',
      button: true,
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: CustomPaint(
            painter: const _DashedBorderPainter(
              color: AppColors.mintBorder,
              radius: 24,
            ),
            child: SizedBox(
              height: 172,
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.yellow,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.yellowEdge,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      AppIcons.cameraFilled,
                      size: 26,
                      color: AppColors.onYellow,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Scatta o scegli una foto',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Inquadra solo i rifiuti: niente volti né targhe.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
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

/// Bordo tratteggiato arrotondato (foto mancante, "Aggiungi descrizione").
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(1),
          Radius.circular(radius),
        ),
      );
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 7), paint);
        d += 12;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class _GpsCard extends StatelessWidget {
  const _GpsCard({
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
    final hasPosition = latitude != null && longitude != null;
    final title = resolving
        ? 'Recupero posizione…'
        : !hasPosition
        ? 'Posizione non disponibile'
        : address ??
              '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}';
    final subtitle = resolving
        ? 'Attendi qualche secondo'
        : !hasPosition
        ? 'Tocca il mirino per riprovare'
        : accuracy != null
        ? 'GPS, precisione ${accuracy!.round()} m'
        : 'GPS';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.greenLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: hasPosition ? AppColors.greenBrand : AppColors.mintBorder,
              borderRadius: BorderRadius.circular(12),
            ),
            child: resolving
                ? const Padding(
                    padding: EdgeInsets.all(11),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(AppIcons.place, size: 22, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 19 / 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.greenDark,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    height: 16 / 12,
                    color: AppColors.greenDark.withAlpha(190),
                  ),
                ),
              ],
            ),
          ),
          if (onRefresh != null)
            IconButton(
              tooltip: 'Aggiorna posizione',
              onPressed: resolving ? null : onRefresh,
              icon: const Icon(
                AppIcons.myLocation,
                size: 22,
                color: AppColors.greenDark,
              ),
            ),
        ],
      ),
    );
  }
}

/// "C'è già una segnalazione a 40 m": invito a confermare quella invece di
/// crearne un doppione.
class _NearbyNotice extends StatelessWidget {
  const _NearbyNotice({required this.meters, required this.onOpen});

  final int meters;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        color: AppColors.purpleLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(AppIcons.info, size: 18, color: AppColors.purpleDark),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontSize: 13,
                      height: 18 / 13,
                      color: AppColors.purpleDark,
                    ),
                    children: [
                      TextSpan(
                        text: 'C\'è già una segnalazione a $meters m. ',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const TextSpan(
                        text:
                            'Se sono gli stessi rifiuti, confermala: vale '
                            'comunque $pointsPerVote punto.',
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onOpen,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.purple,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 36),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const Text('Vedi segnalazione'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddNoteButton extends StatelessWidget {
  const _AddNoteButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: CustomPaint(
          painter: const _DashedBorderPainter(
            color: AppColors.mintBorder,
            radius: 16,
          ),
          child: const SizedBox(
            height: 52,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(AppIcons.edit, size: 18, color: AppColors.greenDark),
                SizedBox(width: 8),
                Text(
                  'Aggiungi una descrizione (facoltativa)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.greenDark,
                  ),
                ),
              ],
            ),
          ),
        ),
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
      padding: EdgeInsets.fromLTRB(16, 14, 16, 18 + bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.greenLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: AppButton(
        label: sending ? 'Invio in corso…' : 'Invia segnalazione',
        icon: AppIcons.send,
        badge: sending ? null : '+$pointsPerReport pt',
        loading: sending,
        onPressed: onSend,
      ),
    );
  }
}

/// Tre riquadri grandi per il tipo di rifiuto; quello scelto diventa verde
/// con la spunta gialla.
class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.selected, required this.onSelected});

  final String? selected;
  final void Function(String?) onSelected;

  static const _types = [
    (
      label: 'Rifiuti abbandonati',
      bg: AppColors.greenLight,
      fg: AppColors.greenDark,
    ),
    (label: 'Discarica abusiva', bg: Color(0xFFFFE7D6), fg: Color(0xFF8A3B0A)),
    (
      label: 'Rifiuti pericolosi',
      bg: AppColors.purpleLight,
      fg: AppColors.purpleDark,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, t) in _types.indexed) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _TypeTile(
              label: t.label,
              bg: t.bg,
              fg: t.fg,
              selected: selected == t.label,
              onTap: () {
                HapticFeedback.selectionClick();
                onSelected(selected == t.label ? null : t.label);
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.label,
    required this.bg,
    required this.fg,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color bg;
  final Color fg;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = selected ? Colors.white : fg;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minHeight: 124),
        decoration: BoxDecoration(
          color: selected ? AppColors.greenBrand : bg,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: selected ? AppColors.greenDark : Colors.transparent,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 14,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.white.withAlpha(41)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            AppIcons.forWasteType(label),
                            size: 26,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            height: 16 / 13,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (selected)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: AppColors.yellow,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        AppIcons.check,
                        size: 14,
                        color: AppColors.onYellow,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _DuplicateChoice { open, sendAnyway }
