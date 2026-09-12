import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/app_user_profile.dart';
import '../models/trashpot_report.dart';
import '../repositories/report_repository.dart';
import '../routes.dart';
import '../services/media_picker_service.dart';
import '../services/photo_upload_service.dart';
import '../state/app_session.dart';
import '../theme/app_colors.dart';
import '../widgets/image_source_bottom_sheet.dart';

class ReportDetailScreen extends StatefulWidget {
  ReportDetailScreen({
    super.key,
    required this.reportId,
    ReportRepository? repository,
    MediaPickerService? mediaPickerService,
    PhotoUploadService? photoUploadService,
  }) : _repository = repository ?? FirestoreReportRepository(),
       _mediaPickerService = mediaPickerService ?? MediaPickerService(),
       _photoUploadService = photoUploadService ?? PhotoUploadService();

  final String reportId;
  final ReportRepository _repository;
  final MediaPickerService _mediaPickerService;
  final PhotoUploadService _photoUploadService;

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  bool _busy = false;

  Future<void> _runAction(
    Future<void> Function(AppUserProfile currentUser, AppSession session) action,
  ) async {
    if (_busy) return;
    final session = AppSessionScope.of(context);
    final authUser = session.currentUser;
    if (authUser == null) {
      session.publishError(
        StateError('Utente non autenticato.'),
        fallback: 'Devi effettuare il login per modificare il report.',
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await action(AppUserProfile.fromAuthUser(authUser), session);
    } catch (e) {
      if (!mounted) return;
      session.publishError(e, fallback: 'Operazione non riuscita.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startCleaning() async {
    await _runAction((currentUser, session) async {
      await widget._repository.startCleaning(
        reportId: widget.reportId,
        actor: currentUser,
      );
      if (!mounted) return;
      session.publishInfo('Pulizia presa in carico.');
    });
  }

  Future<void> _joinEvent() async {
    await _runAction((currentUser, session) async {
      await widget._repository.joinCleanupEvent(
        reportId: widget.reportId,
        participant: currentUser,
      );
      if (!mounted) return;
      session.publishInfo('Partecipazione confermata.');
    });
  }

  Future<void> _scheduleEvent() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: now.add(const Duration(days: 1)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 2))),
    );
    if (pickedTime == null || !mounted) return;

    final scheduledAt = DateTime(
      pickedDate.year, pickedDate.month, pickedDate.day,
      pickedTime.hour, pickedTime.minute,
    );

    await _runAction((currentUser, session) async {
      await widget._repository.scheduleCleanupEvent(
        reportId: widget.reportId,
        creator: currentUser,
        scheduledAt: scheduledAt,
      );
      if (!mounted) return;
      session.publishInfo('Evento creato.');
    });
  }

  Future<void> _completeCleaning() async {
    final source = await showImageSourceBottomSheet(
      context,
      cameraLabel: 'Scatta foto finale',
    );
    if (source == null || !mounted) return;

    final path = await widget._mediaPickerService.pickImagePath(source);
    if (path == null || !mounted) return;

    await _runAction((currentUser, session) async {
      final photoUrl = await widget._photoUploadService.uploadCleanupPhoto(
        localPath: path,
        ownerId: currentUser.uid,
        reportId: widget.reportId,
      );

      await widget._repository.completeCleaning(
        reportId: widget.reportId,
        actor: currentUser,
        cleanupPhotoUrl: photoUrl,
      );

      if (!mounted) return;
      session.publishInfo('Report segnato come ripulito.');
    });
  }

  String _formatDateTime(DateTime value) {
    final dd = value.day.toString().padLeft(2, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${value.year} alle $hh:$min';
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSessionScope.watch(context);
    final currentUser = session.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Dettaglio report')),
      body: StreamBuilder<TrashpotReport?>(
        stream: widget._repository.watchReport(widget.reportId),
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
                    const SizedBox(height: 16),
                    const Text('Errore di rete. Controlla la connessione.'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Torna indietro'),
                    ),
                  ],
                ),
              ),
            );
          }

          final report = snapshot.data;
          if (report == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.delete_outline, size: 48),
                    const SizedBox(height: 16),
                    const Text('Report non disponibile o eliminato.'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Torna indietro'),
                    ),
                  ],
                ),
              ),
            );
          }

          final event = report.event;
          final currentUid = currentUser?.uid;
          final isEventCreator = event != null && currentUid != null && event.creator.uid == currentUid;
          final isCleaningOwner = report.cleaningOwner != null && currentUid != null && report.cleaningOwner!.uid == currentUid;
          final joinedEvent = event?.participants.any((p) => p.uid == currentUid);

          return Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        // Photo header
                        if (report.photoUrl != null)
                          _PhotoHeader(imageUrl: report.photoUrl!, status: report.status),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (report.photoUrl == null)
                                _StatusChipInline(status: report.status),

                              Text(
                                report.title,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Info rows
                              _InfoRow(
                                icon: Icons.place_outlined,
                                text: report.address,
                              ),
                              if (report.dateLabel != null) ...[
                                const SizedBox(height: 6),
                                _InfoRow(
                                  icon: Icons.calendar_today_outlined,
                                  text: report.dateLabel!,
                                ),
                              ],
                              if (report.typeLabel != null) ...[
                                const SizedBox(height: 6),
                                _InfoRow(
                                  icon: Icons.delete_outline,
                                  text: report.typeLabel!,
                                ),
                              ],
                              const SizedBox(height: 12),
                              Divider(color: AppColors.divider, thickness: 0.5, height: 1),
                              const SizedBox(height: 12),

                              if (report.note != null) ...[
                                Text(
                                  'Descrizione',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  report.note!,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Divider(color: AppColors.divider, thickness: 0.5, height: 1),
                                const SizedBox(height: 12),
                              ],

                              // Cleanup photo
                              Text(
                                'Foto dopo la pulizia',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (report.cleanupPhotoUrl != null)
                                _PhotoSection(imageUrl: report.cleanupPhotoUrl!)
                              else
                                Container(
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceWarm,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.divider, width: 0.5, style: BorderStyle.solid),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    'Nessuna foto ancora caricata',
                                    style: TextStyle(fontSize: 13, color: AppColors.textDisabled),
                                  ),
                                ),

                              if (event != null) ...[
                                const SizedBox(height: 16),
                                _EventCard(
                                  event: event,
                                  dateText: _formatDateTime(event.scheduledAt),
                                ),
                              ],

                              if (report.cleaningOwner != null &&
                                  report.status == TrashpotStatus.puliziaInCorso &&
                                  !isCleaningOwner) ...[
                                const SizedBox(height: 12),
                                _InfoRow(
                                  icon: Icons.person_outline,
                                  text: 'Pulizia in corso da parte di ${report.cleaningOwner!.label}.',
                                ),
                              ],

                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Sticky bottom actions
                  _BottomActions(
                    report: report,
                    busy: _busy,
                    isEventCreator: isEventCreator,
                    isCleaningOwner: isCleaningOwner,
                    joinedEvent: joinedEvent,
                    currentUid: currentUid,
                    onStartCleaning: _startCleaning,
                    onScheduleEvent: _scheduleEvent,
                    onJoinEvent: _joinEvent,
                    onCompleteCleaning: _completeCleaning,
                    onOpenMap: () => context.go(AppRoutes.mappa),
                  ),
                ],
              ),

              if (_busy)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black26,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _PhotoHeader extends StatelessWidget {
  const _PhotoHeader({required this.imageUrl, required this.status});

  final String imageUrl;
  final TrashpotStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => _openPhotoFullscreen(context, imageUrl),
      child: SizedBox(
        height: 220,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return ColoredBox(
                  color: cs.surfaceContainerHighest,
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (_, _, _) => ColoredBox(
                color: cs.surfaceContainerHighest,
                child: const Center(
                  child: Icon(Icons.image_not_supported_outlined, size: 40, color: AppColors.textDisabled),
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: _StatusChipInline(status: status),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChipInline extends StatelessWidget {
  const _StatusChipInline({required this.status});

  final TrashpotStatus status;

  @override
  Widget build(BuildContext context) {
    final (:bg, :fg) = AppColors.statusChip(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        trashpotStatusLabel(status).toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w500,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoSection extends StatelessWidget {
  const _PhotoSection({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => _openPhotoFullscreen(context, imageUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return ColoredBox(
                color: cs.surfaceContainerHighest,
                child: const Center(child: CircularProgressIndicator()),
              );
            },
            errorBuilder: (context, error, stackTrace) => ColoredBox(
              color: cs.surfaceContainerHighest,
              child: const Center(
                child: Text('Immagine non disponibile', style: TextStyle(fontSize: 13)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.dateText});

  final CleanupEvent event;
  final String dateText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.greenLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Evento di pulizia',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.greenDark,
            ),
          ),
          const SizedBox(height: 8),
          _InfoRow(icon: Icons.person_outline, text: 'Creato da ${event.creator.label}'),
          const SizedBox(height: 4),
          _InfoRow(icon: Icons.calendar_today_outlined, text: dateText),
          if (event.participants.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Partecipanti (${event.participants.length})',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.greenDark,
              ),
            ),
            const SizedBox(height: 4),
            for (final p in event.participants)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _InfoRow(icon: Icons.person_outline, text: p.label),
              ),
          ],
        ],
      ),
    );
  }
}

void _openPhotoFullscreen(BuildContext context, String imageUrl) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _FullscreenPhotoPage(imageUrl: imageUrl),
    ),
  );
}

class _FullscreenPhotoPage extends StatelessWidget {
  const _FullscreenPhotoPage({required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            },
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Text('Immagine non disponibile', style: TextStyle(color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.report,
    required this.busy,
    required this.isEventCreator,
    required this.isCleaningOwner,
    required this.joinedEvent,
    required this.currentUid,
    required this.onStartCleaning,
    required this.onScheduleEvent,
    required this.onJoinEvent,
    required this.onCompleteCleaning,
    required this.onOpenMap,
  });

  final TrashpotReport report;
  final bool busy;
  final bool isEventCreator;
  final bool isCleaningOwner;
  final bool? joinedEvent;
  final String? currentUid;
  final VoidCallback onStartCleaning;
  final VoidCallback onScheduleEvent;
  final VoidCallback onJoinEvent;
  final VoidCallback onCompleteCleaning;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final s = report.status;
    final event = report.event;

    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (s == TrashpotStatus.segnalata && event == null) ...[
            FilledButton.icon(
              onPressed: busy ? null : onStartCleaning,
              icon: const Icon(Icons.cleaning_services_outlined, size: 18),
              label: const Text('Voglio pulire questa zona'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: busy ? null : onScheduleEvent,
              icon: const Icon(Icons.event_outlined, size: 18),
              label: const Text('Schedula un evento'),
            ),
          ],
          if (s == TrashpotStatus.eventoCreato && event != null && currentUid != null && joinedEvent != true)
            FilledButton.icon(
              onPressed: busy ? null : onJoinEvent,
              icon: const Icon(Icons.group_add_outlined, size: 18),
              label: const Text('Partecipa all\'evento'),
            ),
          if (s == TrashpotStatus.eventoCreato && isEventCreator) ...[
            if (joinedEvent == true) const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: busy ? null : onStartCleaning,
              icon: const Icon(Icons.play_arrow_outlined, size: 18),
              label: const Text('Passa a pulizia in corso'),
            ),
          ],
          if (s == TrashpotStatus.puliziaInCorso && isCleaningOwner)
            FilledButton.icon(
              onPressed: busy ? null : onCompleteCleaning,
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: const Text('Segna come ripulito e carica foto'),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onOpenMap,
            icon: const Icon(Icons.map_outlined, size: 18),
            label: const Text('Apri su mappa'),
          ),
        ],
      ),
    );
  }
}
