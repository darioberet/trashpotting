import 'package:flutter/material.dart';

/// Flusso “Segnala”: form e invio segnalazione (da collegare a Storage + Firestore).
class SegnalaScreen extends StatefulWidget {
  const SegnalaScreen({super.key});

  @override
  State<SegnalaScreen> createState() => _SegnalaScreenState();
}

class _SegnalaScreenState extends State<SegnalaScreen> {
  final _note = TextEditingController();

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
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Invio non ancora collegato al backend.'),
              ),
            );
          },
          icon: const Icon(Icons.send_outlined),
          label: const Text('Invia segnalazione'),
        ),
      ],
    );
  }
}
