import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/trashpot_report.dart';
import '../repositories/moderation_repository.dart';
import '../repositories/report_repository.dart';
import '../repositories/user_profile_repository.dart';
import '../routes.dart';
import '../state/app_session.dart';
import '../theme/app_palette.dart';
import '../widgets/moderation_actions.dart';

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
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Moderazione'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Segnalati'),
              Tab(text: 'Sparite'),
              Tab(text: 'Bloccati'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _FlagsTab(moderation: _moderation, reports: _reports),
            _GoneTab(moderation: _moderation),
            _BlockedTab(moderation: _moderation),
          ],
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
            icon: Icons.verified_user_outlined,
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
                        Icons.flag,
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
                        onPressed: () =>
                            context.push('${AppRoutes.reportDetail}/$reportId'),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('Apri'),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => runModerationAction(
                        context,
                        () => moderation.dismissFlags(reportId),
                        success: 'Segnalazioni archiviate.',
                      ),
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(gone ? 'Archivia' : 'Ignora'),
                    ),
                    if (report != null)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: theme.colorScheme.onError,
                        ),
                        onPressed: () => confirmRemoveReport(
                          context,
                          moderation: moderation,
                          reportId: reportId,
                        ),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Rimuovi'),
                      ),
                    if (report?.reporterUid != null)
                      TextButton.icon(
                        onPressed: () => confirmBlockUser(
                          context,
                          moderation: moderation,
                          uid: report!.reporterUid!,
                        ),
                        icon: const Icon(Icons.block, size: 18),
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
            icon: Icons.check_circle_outline,
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
                          onPressed: () =>
                              context.push('${AppRoutes.reportDetail}/${r.id}'),
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('Apri'),
                        ),
                        FilledButton.icon(
                          onPressed: () => runModerationAction(
                            context,
                            () => moderation.restoreReport(r),
                            success: 'Segnalazione rimessa sulla mappa.',
                          ),
                          icon: const Icon(Icons.restore, size: 18),
                          label: const Text('Ripristina'),
                        ),
                        TextButton.icon(
                          onPressed: () => confirmRemoveReport(
                            context,
                            moderation: moderation,
                            reportId: r.id,
                          ),
                          icon: const Icon(Icons.delete_outline, size: 18),
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
            icon: Icons.people_outline,
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
                leading: const Icon(Icons.block),
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
  const _Message(this.text, {this.icon = Icons.error_outline});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: palette.textDisabled),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
