import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../repositories/report_repository.dart';
import '../repositories/user_profile_repository.dart';
import '../routes.dart';
import '../services/auth_service.dart';
import '../state/app_session.dart';

class ProfiloScreen extends StatefulWidget {
  const ProfiloScreen({super.key});

  @override
  State<ProfiloScreen> createState() => _ProfiloScreenState();
}

class _ProfiloScreenState extends State<ProfiloScreen> {
  final _authService = AuthService();
  final _reportRepository = FirestoreReportRepository();
  final _userProfileRepository = UserProfileRepository();
  bool _deletingAccount = false;

  Future<void> _logout() async {
    try {
      await _authService.signOut();
      if (!mounted) return;
      AppSessionScope.of(context).publishInfo('Logout effettuato.');
    } catch (e) {
      if (!mounted) return;
      AppSessionScope.of(context).publishError(e, fallback: 'Logout non riuscito.');
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final uid = AppSessionScope.of(context).currentUserId;
    if (uid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina account'),
        content: const Text(
          'Questa azione è irreversibile.\n\nIl tuo account verrà eliminato. Le tue segnalazioni rimarranno sulla mappa in forma anonima.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingAccount = true);
    try {
      await _reportRepository.anonymizeUserReports(uid);
      await _userProfileRepository.deleteProfile(uid);
      await _authService.deleteAccount();
      if (!mounted) return;
      AppSessionScope.of(context).publishInfo('Account eliminato.');
    } catch (e) {
      if (!mounted) return;
      AppSessionScope.of(context).publishError(
        e,
        fallback: 'Eliminazione account non riuscita. Potresti dover fare il logout e rientrare prima di eliminare.',
      );
    } finally {
      if (mounted) setState(() => _deletingAccount = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final session = AppSessionScope.watch(context);
    final firebaseReady = session.firebaseReady;
    final userId = session.currentUserId;
    final user = session.currentUser;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const SizedBox(height: 8),
        CircleAvatar(
          radius: 40,
          backgroundColor: cs.primaryContainer,
          foregroundColor: cs.onPrimaryContainer,
          child: Icon(
            userId != null ? Icons.person : Icons.person_outline,
            size: 40,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          user?.displayName ?? (userId != null ? 'Utente' : 'Ospite'),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (user != null) ...[
          const SizedBox(height: 4),
          SelectableText(
            user.email ?? user.uid,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ] else ...[
          const SizedBox(height: 8),
          Text(
            firebaseReady
                ? 'Accedi per salvare segnalazioni e notifiche.'
                : 'Firebase non attivo: vedi strumenti debug.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 32),
        ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: const Text('Notifiche'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(AppRoutes.notifiche),
        ),
        if (kDebugMode)
          ListTile(
            leading: const Icon(Icons.tune_outlined),
            title: const Text('Debug Firebase'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.debugFirebase),
          ),
        if (firebaseReady && userId != null) ...[
          const Divider(height: 24),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _deletingAccount ? null : _logout,
          ),
          ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: cs.error),
            title: Text('Elimina account', style: TextStyle(color: cs.error)),
            trailing: _deletingAccount
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.chevron_right, color: cs.error),
            onTap: _deletingAccount ? null : _confirmDeleteAccount,
          ),
        ],
      ],
    );
  }
}
