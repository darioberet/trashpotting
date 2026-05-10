import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Diagnostica Firebase (ex home di sviluppo).
class DebugFirebaseScreen extends StatefulWidget {
  const DebugFirebaseScreen({
    super.key,
    required this.firebaseReady,
    this.firebaseError,
  });

  final bool firebaseReady;
  final Object? firebaseError;

  @override
  State<DebugFirebaseScreen> createState() => _DebugFirebaseScreenState();
}

class _DebugFirebaseScreenState extends State<DebugFirebaseScreen> {
  String? _status;
  bool _busy = false;

  Future<void> _signInAnonymously() async {
    if (!widget.firebaseReady) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await FirebaseAuth.instance.signInAnonymously();
      setState(() => _status = 'Utente: ${FirebaseAuth.instance.currentUser?.uid}');
    } catch (e) {
      setState(() => _status = 'Auth: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _probeFirestore() async {
    if (!widget.firebaseReady) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await FirebaseFirestore.instance
          .collection('_health')
          .doc('ping')
          .set({'at': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      setState(() => _status = 'Firestore: scrittura _health/ping ok');
    } catch (e) {
      setState(() => _status = 'Firestore: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Firebase'),
        backgroundColor: cs.surfaceContainerHighest,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Stato',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _StatusCard(
              ok: widget.firebaseReady,
              child: widget.firebaseReady
                  ? Text(
                      'Firebase Core attivo.',
                      style: theme.textTheme.bodyMedium,
                    )
                  : Text(
                      'Non connesso.\nUltimo errore: ${widget.firebaseError}',
                      style: theme.textTheme.bodyMedium,
                    ),
            ),
            const SizedBox(height: 24),
            Text(
              'Azioni',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: (!widget.firebaseReady || _busy) ? null : _signInAnonymously,
              icon: const Icon(Icons.person_outline),
              label: const Text('Accesso anonimo'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: (!widget.firebaseReady || _busy) ? null : _probeFirestore,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Test scrittura Firestore'),
            ),
            if (_status != null) ...[
              const SizedBox(height: 16),
              Text(_status!, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.ok, required this.child});

  final bool ok;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ok ? cs.primaryContainer.withValues(alpha: 0.35) : cs.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}
