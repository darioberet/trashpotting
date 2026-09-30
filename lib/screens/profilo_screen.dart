import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../repositories/leaderboard_repository.dart';
import '../repositories/report_repository.dart';
import '../repositories/user_profile_repository.dart';
import '../routes.dart';
import '../services/auth_service.dart';
import '../state/app_session.dart';
import '../theme/app_colors.dart';

String _initialsFrom(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

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
      AppSessionScope.of(
        context,
      ).publishError(e, fallback: 'Logout non riuscito.');
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
        fallback:
            'Eliminazione account non riuscita. Potresti dover fare il logout e rientrare prima di eliminare.',
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

    // Il brand "Trashpotting" è già mostrato dall'AppBar condivisa (stessa
    // meccanica di safe-area della tab Mappa/Classifica): qui il contenuto
    // parte subito, senza header custom manuale.
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Center(
          child: Container(
            width: 104,
            height: 104,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.greenBrand, AppColors.greenDark],
                ),
              ),
              child: user?.photoURL != null
                  ? ClipOval(
                      child: Image.network(
                        user!.photoURL!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    )
                  : Center(
                      child:
                          user?.displayName != null &&
                              user!.displayName!.trim().isNotEmpty
                          ? Text(
                              _initialsFrom(user.displayName!),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              userId != null
                                  ? Icons.person
                                  : Icons.person_outline,
                              size: 44,
                              color: Colors.white,
                            ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          user?.displayName ?? (userId != null ? 'Utente' : 'Ospite'),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (user != null) ...[
          const SizedBox(height: 4),
          SelectableText(
            user.email ?? user.uid,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          if (user.emailVerified) ...[
            const SizedBox(height: 8),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.greenBrand,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.verified, size: 13, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'Email verificata',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
                        Icon(
                          Icons.warning_amber_outlined,
                          size: 14,
                          color: cs.error,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Statistiche non disponibili',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.error,
                          ),
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
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.cardShadow,
                        blurRadius: 16,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          value: done ? '$reports' : '—',
                          label: 'segnalazioni',
                          icon: Icons.assignment_outlined,
                        ),
                      ),
                      Container(width: 1, height: 40, color: AppColors.divider),
                      Expanded(
                        child: _StatTile(
                          value: done ? '$points' : '—',
                          label: 'punti',
                          icon: Icons.star_outline,
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
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 32),
        if (firebaseReady && userId != null)
          _MenuTile(
            iconAsset: 'assets/icons/menu_reports.svg',
            label: 'Le mie segnalazioni',
            onTap: () => context.push(AppRoutes.mieSegnalazioni),
          ),
        // Notifiche, Debug Firebase e Logout non sono nel mockup: nascoste
        // per fedeltà visiva, non rimosse — restano raggiungibili altrove
        // (Notifiche dalla campanella nelle altre tab) finché non si decide
        // dove reinserirle. Per riattivarle: _kShowHiddenMenuItems = true.
        if (_kShowHiddenMenuItems) ...[
          _MenuTile(
            icon: Icons.notifications_outlined,
            label: 'Notifiche',
            onTap: () => context.push(AppRoutes.notifiche),
          ),
        ],
        _MenuTile(
          iconAsset: 'assets/icons/menu_settings.svg',
          label: 'Impostazioni',
          onTap: () => context.push(AppRoutes.impostazioni),
        ),
        _MenuTile(
          iconAsset: 'assets/icons/menu_help.svg',
          label: 'Aiuto e feedback',
          onTap: () => context.push(AppRoutes.aiutoFeedback),
        ),
        if (_kShowHiddenMenuItems && kDebugMode)
          _MenuTile(
            icon: Icons.tune_outlined,
            label: 'Debug Firebase',
            onTap: () => context.push(AppRoutes.debugFirebase),
          ),
        if (firebaseReady && userId != null) ...[
          const Divider(height: 24),
          _MenuTile(
            icon: Icons.logout,
            label: 'Logout',
            onTap: _deletingAccount ? null : _logout,
          ),
          // "Elimina account" nascosta su richiesta: codice mantenuto (non
          // rimosso) per poterla riattivare — vedi _kShowHiddenMenuItems.
          if (_kShowHiddenMenuItems)
            _MenuTile(
              iconAsset: 'assets/icons/menu_delete.svg',
              label: 'Elimina account',
              color: cs.error,
              trailing: _deletingAccount
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: _deletingAccount ? null : _confirmDeleteAccount,
            ),
        ],
      ],
    );
  }
}

const _kShowHiddenMenuItems = false;

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    this.icon,
    this.iconAsset,
    required this.label,
    required this.onTap,
    this.color,
    this.trailing,
  }) : assert(icon != null || iconAsset != null);

  final IconData? icon;
  final String? iconAsset;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? AppColors.textPrimary;
    final iconColor = color ?? AppColors.greenBrand;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: iconAsset != null
            ? SvgPicture.asset(
                iconAsset!,
                width: 18,
                height: 18,
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              )
            : Icon(icon, size: 18, color: iconColor),
      ),
      title: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.w500),
      ),
      trailing:
          trailing ??
          SvgPicture.asset(
            'assets/icons/chevron_right.svg',
            width: 20,
            height: 20,
            colorFilter: ColorFilter.mode(
              color ?? AppColors.textDisabled,
              BlendMode.srcIn,
            ),
          ),
      onTap: onTap,
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
        Icon(icon, size: 20, color: AppColors.greenBrand),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: AppColors.greenBrand,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
