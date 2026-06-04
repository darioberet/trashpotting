import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/location_service.dart';
import '../services/media_picker_service.dart';
import '../services/report_service.dart';
import '../state/app_session.dart';
import '../state/segnala_view_model.dart';

/// Flusso “Segnala”: form e invio segnalazione (da collegare a Storage + Firestore).
class SegnalaScreen extends StatefulWidget {
  SegnalaScreen({
    super.key,
    ReportService? reportService,
    MediaPickerService? mediaPickerService,
    LocationService? locationService,
  })  : _reportService = reportService ?? ReportService(),
        _mediaPickerService = mediaPickerService ?? MediaPickerService(),
        _locationService = locationService ?? LocationService();

  final ReportService _reportService;
  final MediaPickerService _mediaPickerService;
  final LocationService _locationService;

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
  }

  Future<void> _send() async {
    if (_viewModel.sending) return;
    final session = AppSessionScope.of(context);
    await _viewModel.submit(
      firebaseReady: session.firebaseReady,
      note: _note.text,
      uid: session.currentUserId,
    );

    if (_viewModel.infoToken > _seenInfoToken && _viewModel.lastInfo != null) {
      _seenInfoToken = _viewModel.infoToken;
      session.publishInfo(_viewModel.lastInfo!);
      if (_viewModel.lastInfo == 'Segnalazione inviata correttamente.' && mounted) {
        _note.clear();
        _viewModel.clearDraftExtras();
      }
    }
    if (_viewModel.errorToken > _seenErrorToken && _viewModel.lastError != null) {
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
    } catch (e) {
      if (!mounted) return;
      session.publishError(e, fallback: 'Impossibile selezionare la foto.');
    }
  }

  Future<void> _choosePhotoSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Scatta foto'),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Scegli dalla galleria'),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source != null) {
      await _pickPhoto(source);
    }
  }

  Future<void> _resolvePosition() async {
    if (_resolvingPosition) return;
    final session = AppSessionScope.of(context);
    setState(() => _resolvingPosition = true);
    try {
      final p = await widget._locationService.getCurrentPosition();
      if (!mounted) return;
      _viewModel.setLocation(latitude: p.latitude, longitude: p.longitude);
      session.publishInfo('Posizione GPS acquisita.');
    } catch (e) {
      if (!mounted) return;
      session.publishError(e, fallback: 'Impossibile ottenere la posizione GPS.');
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
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              'Nuova segnalazione',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Descrivi il punto, allega una foto e acquisisci la posizione GPS.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _choosePhotoSource,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(
                _viewModel.photoPath == null ? 'Aggiungi foto' : 'Cambia foto',
              ),
            ),
            if (_viewModel.photoPath != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: kIsWeb
                    ? Container(
                        padding: const EdgeInsets.all(12),
                        color: cs.surfaceContainerHighest,
                        child: Text(
                          'Foto selezionata: ${_viewModel.photoPath!.split(RegExp(r'[\\/]')).last}',
                        ),
                      )
                    : Image.file(
                        File(_viewModel.photoPath!),
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _viewModel.clearPhoto,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Rimuovi foto'),
                ),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _resolvingPosition ? null : _resolvePosition,
              icon: const Icon(Icons.my_location_outlined),
              label: Text(
                _resolvingPosition
                    ? 'Recupero posizione...'
                    : (_viewModel.latitude == null
                        ? 'Ottieni posizione GPS'
                        : 'Aggiorna posizione GPS'),
              ),
            ),
            if (_viewModel.latitude != null && _viewModel.longitude != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Lat ${_viewModel.latitude!.toStringAsFixed(6)}, Lng ${_viewModel.longitude!.toStringAsFixed(6)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _viewModel.clearLocation,
                      child: const Text('Rimuovi'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _note,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Note',
                hintText: 'Indirizzo, tipo di rifiuto, orario…',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _viewModel.sending ? null : _send,
              icon: const Icon(Icons.send_outlined),
              label: Text(
                _viewModel.sending ? 'Invio in corso...' : 'Invia segnalazione',
              ),
            ),
          ],
        );
      },
    );
  }
}
