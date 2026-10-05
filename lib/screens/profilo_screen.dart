import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../repositories/leaderboard_repository.dart';
import '../repositories/report_repository.dart';
import '../repositories/user_profile_repository.dart';
import '../routes.dart';
import '../services/auth_service.dart';
import '../services/media_picker_service.dart';
import '../services/photo_upload_service.dart';
import '../services/push_service.dart';
import '../state/app_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../widgets/app_button.dart';
import '../widgets/image_source_bottom_sheet.dart';
import '../widgets/tab_header.dart';
import '../widgets/user_avatar.dart';

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
  final _mediaPickerService = MediaPickerService();
  final _photoUploadService = PhotoUploadService();
  bool _deletingAccount = false;
  Future<_ProfileStats>? _statsFuture;

  String? _loadedStatsForUid;

  void _maybeLoadStats(String uid) {
    if (_loadedStatsForUid == uid) return;
    _loadedStatsForUid = uid;
    setState(() {
      _statsFuture = Future.wait([
        _reportRepository.countByUser(uid),
        _leaderboardRepository.fetchUserPoints(uid),
        _reportRepository.countCleanedBy(uid),
      ]).then((r) => (reports: r[0], points: r[1], cleanups: r[2]));
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

    // La password serve per il ri-login che Firebase esige prima di
    // eliminare un account: chiederla subito evita di cancellare i dati e
    // poi fallire su `requires-recent-login` lasciando l'account a metà.
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => const _DeleteAccountDialog(),
    );
    if (password == null || !mounted) return;

    setState(() => _deletingAccount = true);
    try {
      await _authService.reauthenticateWithPassword(password);
      await _reportRepository.anonymizeUserReports(uid);
      await PushService.instance.deleteUserData(uid);
      await _userProfileRepository.deleteProfile(uid);
      try {
        await _leaderboardRepository.deleteEntry(uid);
      } catch (e) {
        debugPrint('Rimozione dalla classifica non riuscita: $e');
      }
      await _authService.deleteAccount();
      if (!mounted) return;
      AppSessionScope.of(context).publishInfo('Account eliminato.');
    } catch (e) {
      if (!mounted) return;
      AppSessionScope.of(
        context,
      ).publishError(e, fallback: 'Eliminazione account non riuscita.');
    } finally {
      if (mounted) setState(() => _deletingAccount = false);
    }
  }

  bool _uploadingPhoto = false;

  /// Cambia la foto profilo (visibile solo a te, nel Profilo).
  Future<void> _changePhoto() async {
    final session = AppSessionScope.of(context);
    final uid = session.currentUserId;
    if (uid == null || _uploadingPhoto) return;
    final source = await showImageSourceBottomSheet(context);
    if (source == null || !mounted) return;
    final path = await _mediaPickerService.pickImagePath(source);
    if (path == null || !mounted) return;
    setState(() => _uploadingPhoto = true);
    try {
      final url = await _photoUploadService.uploadProfilePhoto(
        localPath: path,
        ownerId: uid,
      );
      await _authService.updateProfile(photoURL: url);
      session.refreshCurrentUser();
      if (!mounted) return;
      session.publishInfo('Foto profilo aggiornata.');
    } catch (e) {
      if (!mounted) return;
      session.publishError(e, fallback: 'Foto non aggiornata.');
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSessionScope.watch(context);
    final firebaseReady = session.firebaseReady;
    final userId = session.currentUserId;
    final user = session.currentUser;
    final username = session.username?.trim();
    final name = username != null && username.isNotEmpty
        ? username
        : (userId != null ? 'Utente' : 'Ospite');
    final topInset = MediaQuery.of(context).padding.top;

    if (userId != null) _maybeLoadStats(userId);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: SingleChildScrollView(
        child: Stack(
          children: [
            // Fascia verde chiaro dietro header e avatar; la card sotto ci
            // sale sopra a metà.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: topInset + 222,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.greenLight,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(32),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, topInset + 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TabHeader(
                    title: 'Profilo',
                    actions: [
                      HeaderCircleButton(
                        icon: AppIcons.settings,
                        tooltip: 'Impostazioni',
                        onPressed: () => context.push(AppRoutes.impostazioni),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _ProfileAvatar(
                        name: name,
                        seed: userId ?? 'guest',
                        photoUrl: user?.photoURL,
                        uploading: _uploadingPhoto,
                        onChange: userId == null ? null : _changePhoto,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 26,
                                height: 32 / 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (user?.email != null)
                              Text(
                                user!.email!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 18 / 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            if (user?.emailVerified == true) ...[
                              const SizedBox(height: 6),
                              Container(
                                height: 24,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.greenBrand,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      AppIcons.check,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Email verificata',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (user == null)
                              Text(
                                firebaseReady
                                    ? 'Accedi per salvare segnalazioni e '
                                          'notifiche.'
                                    : 'Firebase non attivo: vedi strumenti '
                                          'debug.',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (user != null && _statsFuture != null)
                    FutureBuilder<_ProfileStats>(
                      future: _statsFuture,
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return _StatsError(
                            onRetry: () => setState(() {
                              _loadedStatsForUid = null;
                              _maybeLoadStats(userId!);
                            }),
                          );
                        }
                        final stats = snap.data;
                        if (stats == null) {
                          return const SizedBox(
                            height: 120,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final allDone = stats.reports > 0 && stats.cleanups > 0;
                        return allDone
                            ? _StatsCard(stats: stats)
                            : _FirstStepsCard(
                                stats: stats,
                                emailVerified: user.emailVerified,
                                onReport: () => context.push(AppRoutes.segnala),
                              );
                      },
                    ),
                  const SizedBox(height: 16),
                  _MenuCard(
                    children: [
                      if (firebaseReady && userId != null)
                        _MenuTile(
                          icon: AppIcons.myReports,
                          label: 'Le mie segnalazioni',
                          bg: AppColors.greenLight,
                          fg: AppColors.greenDark,
                          onTap: () => context.push(AppRoutes.mieSegnalazioni),
                        ),
                      if (firebaseReady && userId != null && session.isAdmin)
                        _MenuTile(
                          icon: AppIcons.shield,
                          label: 'Moderazione',
                          bg: AppColors.blueLight,
                          fg: AppColors.blueText,
                          onTap: () => context.push(AppRoutes.moderazione),
                        ),
                      _MenuTile(
                        icon: AppIcons.help,
                        label: 'Aiuto e feedback',
                        bg: AppColors.purpleLight,
                        fg: AppColors.purpleDark,
                        onTap: () => context.push(AppRoutes.aiutoFeedback),
                      ),
                      if (firebaseReady && userId != null)
                        _MenuTile(
                          icon: AppIcons.logout,
                          label: 'Logout',
                          bg: AppColors.yellowLight,
                          fg: AppColors.yellowText,
                          onTap: _deletingAccount ? null : _logout,
                        ),
                    ],
                  ),
                  if (firebaseReady && userId != null) ...[
                    const SizedBox(height: 12),
                    // Obbligatoria per Google Play: un'app che permette di
                    // creare un account deve permettere di eliminarlo.
                    _MenuCard(
                      children: [
                        _MenuTile(
                          icon: AppIcons.delete,
                          label: 'Elimina account',
                          bg: AppColors.redLight,
                          fg: AppColors.redText,
                          labelColor: AppColors.redText,
                          trailing: _deletingAccount
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : null,
                          onTap: _deletingAccount
                              ? null
                              : _confirmDeleteAccount,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef _ProfileStats = ({int reports, int points, int cleanups});

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.name,
    required this.seed,
    required this.photoUrl,
    required this.uploading,
    required this.onChange,
  });

  final String name;
  final String seed;
  final String? photoUrl;
  final bool uploading;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 4,
            top: 4,
            child: photoUrl != null
                ? Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(color: Colors.white, spreadRadius: 4),
                      ],
                      image: DecorationImage(
                        image: CachedNetworkImageProvider(photoUrl!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                : UserAvatar(
                    name: name,
                    seed: seed,
                    size: 80,
                    ring: (color: Colors.white, width: 4),
                  ),
          ),
          if (onChange != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: Semantics(
                button: true,
                label: 'Cambia foto profilo',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: uploading ? null : onChange,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.greenBrand,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.greenLight, width: 3),
                    ),
                    child: uploading
                        ? const Padding(
                            padding: EdgeInsets.all(6),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            AppIcons.camera,
                            size: 15,
                            color: Colors.white,
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Inizia a fare la differenza": i primi passi finché non sono tutti fatti.
class _FirstStepsCard extends StatelessWidget {
  const _FirstStepsCard({
    required this.stats,
    required this.emailVerified,
    required this.onReport,
  });

  final _ProfileStats stats;
  final bool emailVerified;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.forest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            top: -6,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
              ),
              child: Container(
                width: 104,
                height: 104,
                color: const Color(0xFFFDFDFB),
                padding: const EdgeInsets.all(4),
                child: SvgPicture.asset(
                  'assets/onboarding/segnala.svg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.only(right: 100),
                  child: Text(
                    'Inizia a fare la differenza',
                    style: TextStyle(
                      fontSize: 20,
                      height: 26 / 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 4, bottom: 14, right: 100),
                  child: Text(
                    'Completa i primi passi e scala la classifica.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 18 / 13,
                      color: AppColors.mintText,
                    ),
                  ),
                ),
                _StepRow(
                  done: emailVerified,
                  title: 'Verifica la tua email',
                  subtitle: emailVerified
                      ? 'Account attivo'
                      : 'Apri il link che ti abbiamo inviato',
                ),
                const SizedBox(height: 6),
                _StepRow(
                  done: stats.reports > 0,
                  title: 'Fai la prima segnalazione',
                  subtitle: 'Una foto e la posizione, 10 secondi',
                  points: pointsPerReport,
                ),
                const SizedBox(height: 6),
                _StepRow(
                  done: stats.cleanups > 0,
                  title: 'Completa la prima pulizia',
                  subtitle: 'Prendila in carico dalla mappa',
                  points: pointsPerCleanup,
                ),
                if (stats.reports == 0) ...[
                  const SizedBox(height: 14),
                  AppButton(
                    label: 'Segnala ora',
                    icon: AppIcons.addPlace,
                    height: 52,
                    onPressed: onReport,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.done,
    required this.title,
    required this.subtitle,
    this.points,
  });

  final bool done;
  final String title;
  final String subtitle;
  final int? points;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$title: ${done ? 'fatto' : 'da fare'}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: done ? AppColors.greenLight : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            done
                ? Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppColors.greenBrand,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      AppIcons.check,
                      size: 16,
                      color: Colors.white,
                    ),
                  )
                : Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.mintBorder, width: 2),
                    ),
                  ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      height: 19 / 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary.withAlpha(done ? 153 : 255),
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 16 / 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (done)
              const Text(
                'Fatto',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.greenDark,
                ),
              )
            else if (points != null)
              Container(
                height: 22,
                padding: const EdgeInsets.only(left: 6, right: 8),
                decoration: BoxDecoration(
                  color: AppColors.yellow,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      AppIcons.starFilled,
                      size: 12,
                      color: AppColors.onYellow,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '+$points pt',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onYellow,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// I tuoi numeri, quando i primi passi sono completati.
class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});

  final _ProfileStats stats;

  @override
  Widget build(BuildContext context) {
    Widget tile(int value, String label) => Expanded(
      child: Semantics(
        label: '$value $label',
        excludeSemantics: true,
        child: Column(
          children: [
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 30,
                height: 1.1,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                color: Colors.white,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.mintText,
              ),
            ),
          ],
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: AppColors.forest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Il tuo contributo',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              tile(
                stats.reports,
                stats.reports == 1 ? 'segnalazione' : 'segnalazioni',
              ),
              tile(stats.cleanups, stats.cleanups == 1 ? 'pulizia' : 'pulizie'),
              tile(stats.points, 'punti'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsError extends StatelessWidget {
  const _StatsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(AppIcons.error, size: 16, color: AppColors.redText),
        const SizedBox(width: 6),
        const Text(
          'Statistiche non disponibili',
          style: TextStyle(fontSize: 13, color: AppColors.redText),
        ),
        TextButton(onPressed: onRetry, child: const Text('Riprova')),
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: AppColors.mintBorder, offset: Offset(0, 2)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(children: children),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.bg,
    required this.fg,
    required this.onTap,
    this.labelColor,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;
  final Color? labelColor;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: fg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: labelColor ?? AppColors.textPrimary,
                  ),
                ),
              ),
              trailing ??
                  const Icon(
                    AppIcons.chevronRight,
                    size: 18,
                    color: AppColors.textDisabled,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _password.text;
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Elimina account'),
      // Scorrevole: con la tastiera aperta il dialog si accorcia e il
      // contenuto altrimenti sfora sopra i pulsanti.
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Questa azione è irreversibile.\n\nIl tuo account e il tuo posto in '
            'classifica verranno eliminati. Le tue segnalazioni rimarranno '
            'sulla mappa in forma anonima.\n\nInserisci la password per '
            'confermare.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            obscureText: _obscure,
            autofocus: true,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Mostra password' : 'Nascondi password',
                icon: Icon(_obscure ? AppIcons.hidden : AppIcons.visible),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        ListenableBuilder(
          listenable: _password,
          builder: (context, _) => FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
              minimumSize: const Size(88, 40),
            ),
            onPressed: _password.text.isEmpty ? null : _submit,
            child: const Text('Elimina'),
          ),
        ),
      ],
    );
  }
}
