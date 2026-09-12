import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../repositories/leaderboard_repository.dart';
import '../repositories/report_repository.dart';
import '../repositories/user_profile_repository.dart';
import '../routes.dart';
import '../services/auth_service.dart';
import '../state/app_session.dart';
import '../theme/app_colors.dart';

class ProfiloScreen extends StatefulWidget {
  const ProfiloScreen({super.key});

  @override
  State<ProfiloScreen> createState() => _ProfiloScreenState();
}

class _ProfiloScreenState extends State<ProfiloScreen> {
  final _authService = AuthService();
  final _reportRepository = FirestoreReportRepository();
  final _userProfileRepository = UserProfileRepository();
  final _leaderboardRepository = FirestoreLeaderboardRepository();
  bool _deletingAccount = false;
  Future<({int reports, int points})>? _statsFuture;

  String? _loadedStatsForUid;

  void _maybeLoadStats(String uid) {
    if (_loadedStatsForUid == uid) return;
    _loadedStatsForUid = uid;
    setState(() {
      _statsFuture = Future.wait([
        _reportRepository.countByUser(uid),
        _leaderboardRepository.fetchUserPoints(uid),
      ]).then((results) => (reports: results[0], points: results[1]));
    });
  }

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
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              minimumSize: const Size(88, 40),
            ),
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

    if (userId != null) _maybeLoadStats(userId);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const SizedBox(height: 8),
        CircleAvatar(
          radius: 40,
          backgroundColor: cs.primaryContainer,
          foregroundColor: cs.onPrimaryContainer,
          backgroundImage: user?.photoURL != null
              ? NetworkImage(user!.photoURL!)
              : null,
          child: user?.photoURL == null
              ? Icon(
                  userId != null ? Icons.person : Icons.person_outline,
                  size: 40,
                )
              : null,
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
          const SizedBox(height: 20),
          if (_statsFuture != null)
            FutureBuilder<({int reports, int points})>(
              future: _statsFuture,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.warning_amber_outlined, size: 14, color: cs.error),
                        const SizedBox(width: 6),
                        Text(
                          'Statistiche non disponibili',
                          style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(() {
                            _loadedStatsForUid = null;
                            _maybeLoadStats(userId!);
                          }),
                          child: Text(
                            'Riprova',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.greenBrand,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final done = snap.connectionState == ConnectionState.done;
                final reports = snap.data?.reports ?? 0;
                final points = snap.data?.points ?? 0;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.greenLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          value: done ? '$reports' : '—',
                          label: 'Segnalazioni',
                          icon: Icons.add_location_alt_outlined,
                        ),
                      ),
                      Container(width: 1, height: 40, color: AppColors.divider),
                      Expanded(
                        child: _StatTile(
                          value: done ? '$points' : '—',
                          label: 'Punti',
                          icon: Icons.emoji_events_outlined,
                        ),
                      ),
                    ],
                  ),
                );
              },
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

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 22, color: AppColors.greenBrand),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.greenBrand,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.greenDark,
          ),
        ),
      ],
    );
  }
}
