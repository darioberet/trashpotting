import 'package:flutter/material.dart';

import '../services/report_service.dart';
import '../state/app_session.dart';

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
  bool _sending = false;

  Future<void> _send() async {
    if (_sending) return;
    final session = AppSessionScope.of(context);
    if (!session.firebaseReady) {
      session.publishInfo('Backend non disponibile: verifica Firebase e riprova.');
      return;
    }

    setState(() => _sending = true);
    try {
      await widget._reportService.submit(
        note: _note.text,
        uid: session.currentUserId,
      );
      if (!mounted) return;
      _note.clear();
      session.publishInfo('Segnalazione inviata correttamente.');
    } catch (e) {
      if (!mounted) return;
      session.publishError(e, fallback: 'Invio segnalazione non riuscito.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
          onPressed: _sending ? null : _send,
          icon: const Icon(Icons.send_outlined),
          label: Text(_sending ? 'Invio in corso...' : 'Invia segnalazione'),
        ),
      ],
    );
  }
}
