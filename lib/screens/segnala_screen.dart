import 'dart:async';
import 'dart:io';

import 'package:geocoding/geocoding.dart' as geo;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/location_service.dart';
import '../services/media_picker_service.dart';
import '../services/report_service.dart';
import '../services/image_processing_service.dart';
import '../state/app_session.dart';
import '../state/segnala_view_model.dart';
import '../theme/app_colors.dart';
import '../widgets/image_source_bottom_sheet.dart';

class SegnalaScreen extends StatefulWidget {
  SegnalaScreen({
    super.key,
    ReportService? reportService,
    MediaPickerService? mediaPickerService,
    LocationService? locationService,
    ImageProcessingService? imageProcessingService,
  }) : _reportService = reportService ?? ReportService(),
       _mediaPickerService = mediaPickerService ?? MediaPickerService(),
       _locationService = locationService ?? LocationService(),
       _imageProcessingService =
           imageProcessingService ?? const ImageProcessingService();

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

  Future<void> _send() async {
    if (_viewModel.sending) return;
    final session = AppSessionScope.of(context);

    final hasLocation = await _resolvePosition(forceRefresh: true);
    if (!hasLocation || !mounted) return;

    await _viewModel.submit(
      firebaseReady: session.firebaseReady,
      note: _note.text,
      uid: session.currentUserId,
      displayName: session.currentUser?.displayName,
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
            content: Text(
              'DEBUG — stima: ${kb.toStringAsFixed(1)} KB',
            ),
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
        final placemarks = await geo.placemarkFromCoordinates(p.latitude, p.longitude);
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
        return Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: AbsorbPointer(
                    absorbing: _viewModel.sending,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      children: [
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
                          decoration: const InputDecoration(
                            hintText: 'Descrivi brevemente i rifiuti che hai trovato...',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _ModerationNotice(),
                      ],
                    ),
                  ),
                ),

                // Sticky bottom CTA
                _StickyBottomBar(
                  sending: _viewModel.sending,
                  onSend: _send,
                ),
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
      return Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: kIsWeb
                  ? Container(
                      height: 120,
                      color: AppColors.surfaceWarm,
                      alignment: Alignment.center,
                      child: Text(
                        photoPath!.split(RegExp(r'[\\/]')).last,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    )
                  : Image.file(
                      File(photoPath!),
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Rimuovi foto', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.surfaceWarm,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider, width: 1.5, style: BorderStyle.solid),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_outlined, size: 28, color: AppColors.textDisabled),
            SizedBox(height: 8),
            Text(
              'Tocca per aggiungere foto',
              style: TextStyle(fontSize: 13, color: AppColors.textDisabled),
            ),
          ],
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
  });

  final bool resolving;
  final double? latitude;
  final double? longitude;

  @override
  Widget build(BuildContext context) {
    if (resolving) {
      return Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: AppColors.greenBrand,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Recupero posizione...',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
    }

    if (latitude == null || longitude == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.greenLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.greenBrand,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.place_outlined, size: 13, color: AppColors.greenDark),
          const SizedBox(width: 4),
          Text(
            'Lat ${latitude!.toStringAsFixed(5)}, Lng ${longitude!.toStringAsFixed(5)}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.greenDark,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModerationNotice extends StatelessWidget {
  const _ModerationNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.amberLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 3),
            decoration: const BoxDecoration(
              color: AppColors.amberDot,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'La tua segnalazione sarà visibile sulla mappa dopo la verifica.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: AppColors.amberText,
                height: 1.5,
              ),
            ),
          ),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: FilledButton.icon(
        onPressed: sending ? null : onSend,
        icon: sending
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.selected, required this.onSelected});

  final String? selected;
  final void Function(String?) onSelected;

  static const _types = [
    'Rifiuti abbandonati',
    'Discarica abusiva',
    'Rifiuti pericolosi',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final t in _types)
          ChoiceChip(
            label: Text(t, style: const TextStyle(fontSize: 12)),
            selected: selected == t,
            onSelected: (on) => onSelected(on ? t : null),
            selectedColor: AppColors.greenLight,
            labelStyle: TextStyle(
              color: selected == t ? AppColors.greenDark : AppColors.textSecondary,
              fontWeight: selected == t ? FontWeight.w600 : FontWeight.normal,
            ),
            side: BorderSide(
              color: selected == t ? AppColors.greenBrand : AppColors.divider,
            ),
            backgroundColor: Colors.transparent,
            showCheckmark: false,
          ),
      ],
    );
  }
}
