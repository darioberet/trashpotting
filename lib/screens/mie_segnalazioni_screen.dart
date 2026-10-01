import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/trashpot_report.dart';
import '../repositories/report_repository.dart';
import '../routes.dart';
import '../state/app_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';

class MieSegnalazioniScreen extends StatelessWidget {
  MieSegnalazioniScreen({super.key, ReportRepository? repository})
    : _repository = repository ?? FirestoreReportRepository();

  final ReportRepository _repository;

  @override
  Widget build(BuildContext context) {
    final uid = AppSessionScope.of(context).currentUserId;

    return Scaffold(
      appBar: AppBar(title: const Text('Le mie segnalazioni')),
      body: uid == null
          ? Center(
              child: Text(
                'Accedi per vedere le tue segnalazioni.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
            )
          : StreamBuilder<List<TrashpotReport>>(
              stream: _repository.watchReportsByUser(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_outlined, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            'Errore di rete. Riprova più tardi.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final reports = snapshot.data ?? const <TrashpotReport>[];
                if (reports.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.assignment_outlined,
                            size: 56,
                            color: context.palette.divider,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Non hai ancora inviato segnalazioni.',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: reports.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final r = reports[i];
                    return _MyReportCard(
                      report: r,
                      onTap: () =>
                          context.push('${AppRoutes.reportDetail}/${r.id}'),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _MyReportCard extends StatelessWidget {
  const _MyReportCard({required this.report, required this.onTap});

  final TrashpotReport report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (:bg, :fg) = AppColors.statusChip(report.status);

    return Material(
      color: context.palette.surfaceWarm,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: report.photoUrl != null
                    ? Image.network(
                        report.photoUrl!,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 52,
                          height: 52,
                          color: context.palette.divider,
                          child: Icon(
                            Icons.image_outlined,
                            size: 20,
                            color: context.palette.textDisabled,
                          ),
                        ),
                      )
                    : Container(
                        width: 52,
                        height: 52,
                        color: context.palette.divider,
                        child: Icon(
                          Icons.image_outlined,
                          size: 20,
                          color: context.palette.textDisabled,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      report.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      report.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  trashpotStatusLabel(report.status).toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: fg,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
