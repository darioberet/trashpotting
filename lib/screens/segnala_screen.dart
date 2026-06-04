import 'package:flutter/material.dart';

import '../services/report_service.dart';
import '../state/app_session.dart';
import '../state/segnala_view_model.dart';

/// Flusso “Segnala”: form e invio segnalazione (da collegare a Storage + Firestore).
class SegnalaScreen extends StatefulWidget {
  SegnalaScreen({super.key, ReportService? reportService})
      : _reportService = reportService ?? ReportService();

  final ReportService _reportService;

  @override
  State<SegnalaScreen> createState() => _SegnalaScreenState();
}

class _SegnalaScreenState extends State<SegnalaScreen> {
  final _note = TextEditingController();
  late final SegnalaViewModel _viewModel;
  int _seenInfoToken = 0;
  int _seenErrorToken = 0;

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
              'Descrivi il punto e allega foto quando colleghi Storage.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Aggiungi foto (prossimo step)'),
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
