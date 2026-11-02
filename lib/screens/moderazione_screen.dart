import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../models/trashpot_report.dart';
import '../repositories/moderation_repository.dart';
import '../repositories/report_repository.dart';
import '../repositories/user_profile_repository.dart';
import '../routes.dart';
import '../state/app_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../widgets/moderation_actions.dart';
import '../widgets/tab_header.dart';
import '../theme/app_icons.dart';

/// Area admin: contenuti segnalati dagli utenti e utenti bloccati.
/// Raggiungibile solo con la custom claim `admin` (vedi redirect in app.dart).
class ModerazioneScreen extends StatelessWidget {
  ModerazioneScreen({
    super.key,
    ModerationRepository? moderationRepository,
    ReportRepository? reportRepository,
  }) : _moderation = moderationRepository ?? ModerationRepository(),
       _reports = reportRepository ?? FirestoreReportRepository();

  final ModerationRepository _moderation;
  final ReportRepository _reports;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BackHeader(title: 'Moderazione'),
                const _PillTabs(tabs: ['Segnalati', 'Sparite', 'Bloccati']),
                Expanded(
                  child: TabBarView(
                    children: [
                      _FlagsTab(moderation: _moderation, reports: _reports),
                      _GoneTab(moderation: _moderation),
                      _BlockedTab(moderation: _moderation),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FlagsTab extends StatelessWidget {
  const _FlagsTab({required this.moderation, required this.reports});

  final ModerationRepository moderation;
  final ReportRepository reports;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ContentFlag>>(
      stream: moderation.watchOpenFlags(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const _Message('Impossibile caricare le segnalazioni.');
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        // Una card per report, con tutte le segnalazioni ricevute; i report
        // più segnalati in cima.
        final byReport = <String, List<ContentFlag>>{};
        for (final flag in snap.data!) {
          byReport.putIfAbsent(flag.reportId, () => []).add(flag);
        }
        final groups = byReport.entries.toList()
          ..sort((a, b) => b.value.length.compareTo(a.value.length));
        if (groups.isEmpty) {
          return const _Message(
            'Nessun contenuto da controllare.',
            icon: AppIcons.shieldOk,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: groups.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _FlaggedReportCard(
            reportId: groups[i].key,
            flags: groups[i].value,
            moderation: moderation,
            reports: reports,
          ),
        );
      },
    );
  }
}

class _FlaggedReportCard extends StatelessWidget {
  const _FlaggedReportCard({
    required this.reportId,
    required this.flags,
    required this.moderation,
    required this.reports,
  });

  final String reportId;
  final List<ContentFlag> flags;
  final ModerationRepository moderation;
  final ReportRepository reports;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final reasons = <String, int>{};
    for (final f in flags) {
      reasons[f.reason] = (reasons[f.reason] ?? 0) + 1;
    }

    return StreamBuilder<TrashpotReport?>(
      stream: reports.watchReport(reportId),
      builder: (context, snap) {
        final report = snap.data;
        final gone =
            snap.connectionState == ConnectionState.active && report == null;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        gone
                            ? 'Segnalazione già rimossa'
                            : (report?.title ?? 'Caricamento…'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      avatar: Icon(
                        AppIcons.flagFilled,
                        size: 16,
                        color: theme.colorScheme.error,
                      ),
                      label: Text('${flags.length}'),
                      // Il chipTheme globale non dà colore al testo.
                      labelStyle: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                if (report != null) ...[
                  const SizedBox(height: 4),
                  _AuthorLine(uid: report.reporterUid),
                ],
                const SizedBox(height: 8),
                for (final e in reasons.entries)
                  Text(
                    '• ${e.key}${e.value > 1 ? ' (${e.value})' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (report != null)
                      OutlinedButton.icon(
                        style: _compactOutlined,
                        onPressed: () =>
                            context.push('${AppRoutes.reportDetail}/$reportId'),
                        icon: const Icon(AppIcons.openExternal, size: 18),
                        label: const Text('Apri'),
                      ),
                    OutlinedButton.icon(
                      style: _compactOutlined,
                      onPressed: () => runModerationAction(
                        context,
                        () => moderation.dismissFlags(reportId),
                        success: 'Segnalazioni archiviate.',
                      ),
                      icon: const Icon(AppIcons.check, size: 18),
                      label: Text(gone ? 'Archivia' : 'Ignora'),
                    ),
                    if (report != null)
                      FilledButton.icon(
                        style: _compactFilled.copyWith(
                          backgroundColor: const WidgetStatePropertyAll(
                            AppColors.redPin,
                          ),
                          foregroundColor: const WidgetStatePropertyAll(
                            Colors.white,
                          ),
                        ),
                        onPressed: () => confirmRemoveReport(
                          context,
                          moderation: moderation,
                          reportId: reportId,
                        ),
                        icon: const Icon(AppIcons.delete, size: 18),
                        label: const Text('Rimuovi'),
                      ),
                    if (report?.reporterUid != null)
                      TextButton.icon(
                        onPressed: () => confirmBlockUser(
                          context,
                          moderation: moderation,
                          uid: report!.reporterUid!,
                        ),
                        icon: const Icon(AppIcons.block, size: 18),
                        label: const Text('Blocca autore'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AuthorLine extends StatelessWidget {
  const _AuthorLine({required this.uid});

  final String? uid;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: context.palette.textSecondary);
    if (uid == null) return Text('Autore: account eliminato', style: style);
    return FutureBuilder(
      future: UserProfileRepository().fetchProfile(uid!),
      builder: (context, snap) =>
          Text('Autore: ${snap.data?.label ?? '…'}', style: style),
    );
  }
}

/// Segnalazioni nascoste perché la community ha indicato "non c'è più".
class _GoneTab extends StatelessWidget {
  const _GoneTab({required this.moderation});

  final ModerationRepository moderation;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TrashpotReport>>(
      stream: moderation.watchGoneReports(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const _Message('Impossibile caricare le segnalazioni.');
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final reports = snap.data!;
        if (reports.isEmpty) {
          return const _Message(
            'Nessuna segnalazione sparita.',
            icon: AppIcons.statusCleaned,
          );
        }
        final theme = Theme.of(context);
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final r = reports[i];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _AuthorLine(uid: r.reporterUid),
                    Text(
                      '${r.goneVotes} "non c\'è più" · '
                      '${r.confirmations} conferme',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          style: _compactOutlined,
                          onPressed: () =>
                              context.push('${AppRoutes.reportDetail}/${r.id}'),
                          icon: const Icon(AppIcons.openExternal, size: 18),
                          label: const Text('Apri'),
                        ),
                        FilledButton.icon(
                          style: _compactFilled,
                          onPressed: () => runModerationAction(
                            context,
                            () => moderation.restoreReport(r),
                            success: 'Segnalazione rimessa sulla mappa.',
                          ),
                          icon: const Icon(AppIcons.restore, size: 18),
                          label: const Text('Ripristina'),
                        ),
                        TextButton.icon(
                          onPressed: () => confirmRemoveReport(
                            context,
                            moderation: moderation,
                            reportId: r.id,
                          ),
                          icon: const Icon(AppIcons.delete, size: 18),
                          label: const Text('Rimuovi'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _BlockedTab extends StatelessWidget {
  const _BlockedTab({required this.moderation});

  final ModerationRepository moderation;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BlockedUser>>(
      stream: moderation.watchBlockedUsers(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const _Message('Impossibile caricare gli utenti bloccati.');
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final users = snap.data!;
        if (users.isEmpty) {
          return const _Message(
            'Nessun utente bloccato.',
            icon: AppIcons.users,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final u = users[i];
            final at = u.blockedAt;
            return Card(
              child: ListTile(
                leading: const Icon(AppIcons.block),
                title: Text(u.username ?? 'Utente'),
                subtitle: at == null
                    ? null
                    : Text(
                        'Bloccato il ${at.day.toString().padLeft(2, '0')}/'
                        '${at.month.toString().padLeft(2, '0')}/${at.year}',
                      ),
                trailing: TextButton(
                  onPressed: () => runModerationAction(
                    context,
                    () => moderation.setBlocked(
                      uid: u.uid,
                      blocked: false,
                      adminUid: AppSessionScope.of(context).currentUserId!,
                    ),
                    success: '${u.username ?? 'Utente'} sbloccato.',
                  ),
                  child: const Text('Sblocca'),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, {this.icon = AppIcons.error});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: AppColors.greenLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AppColors.greenBrand),
            ),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// I pulsanti del tema sono larghi quanto lo schermo: qui stanno affiancati.
final _compactOutlined = OutlinedButton.styleFrom(
  minimumSize: const Size(0, 40),
  padding: const EdgeInsets.symmetric(horizontal: 14),
  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
);

final _compactFilled = FilledButton.styleFrom(
  minimumSize: const Size(0, 40),
  padding: const EdgeInsets.symmetric(horizontal: 14),
  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
);

/// Schede a pillola: la selezionata è verde piena.
class _PillTabs extends StatelessWidget {
  const _PillTabs({required this.tabs});

  final List<String> tabs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(color: AppColors.mintBorder, offset: Offset(0, 2)),
          ],
        ),
        child: TabBar(
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: AppColors.greenBrand,
            borderRadius: BorderRadius.circular(999),
          ),
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          splashBorderRadius: BorderRadius.circular(999),
          tabs: [for (final t in tabs) Tab(height: 40, text: t)],
        ),
      ),
    );
  }
}
