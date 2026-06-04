import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/firebase_health_service.dart';
import '../state/app_session.dart';

/// Diagnostica Firebase (ex home di sviluppo).
class DebugFirebaseScreen extends StatefulWidget {
  DebugFirebaseScreen({
    super.key,
    AuthService? authService,
    FirebaseHealthService? healthService,
  })  : _authService = authService ?? AuthService(),
        _healthService = healthService ?? FirebaseHealthService();

  final AuthService _authService;
  final FirebaseHealthService _healthService;

  @override
  State<DebugFirebaseScreen> createState() => _DebugFirebaseScreenState();
}

class _DebugFirebaseScreenState extends State<DebugFirebaseScreen> {
  String? _status;
  bool _busy = false;

  Future<void> _signInAnonymously() async {
    final session = AppSessionScope.of(context);
    if (!session.firebaseReady) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final cred = await widget._authService.signInAnonymously();
      setState(() => _status = 'Utente: ${cred.user?.uid}');
    } catch (e) {
      session.publishError(e, fallback: 'Accesso anonimo non riuscito.');
      setState(() => _status = 'Auth: errore');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _probeFirestore() async {
    final session = AppSessionScope.of(context);
    if (!session.firebaseReady) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await widget._healthService.probeWrite();
      setState(() => _status = 'Firestore: scrittura _health/ping ok');
    } catch (e) {
      session.publishError(e, fallback: 'Test Firestore non riuscito.');
      setState(() => _status = 'Firestore: errore');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSessionScope.watch(context);
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
              ok: session.firebaseReady,
              child: session.firebaseReady
                  ? Text(
                      'Firebase Core attivo.',
                      style: theme.textTheme.bodyMedium,
                    )
                  : Text(
                      'Non connesso.\nUltimo errore: ${session.firebaseError}',
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
              onPressed: (!session.firebaseReady || _busy) ? null : _signInAnonymously,
              icon: const Icon(Icons.person_outline),
              label: const Text('Accesso anonimo'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: (!session.firebaseReady || _busy) ? null : _probeFirestore,
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
