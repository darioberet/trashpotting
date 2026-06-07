import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_user_profile.dart';
import '../models/trashpot_report.dart';
import '../repositories/report_repository.dart';
import '../services/media_picker_service.dart';
import '../services/photo_upload_service.dart';
import '../state/app_session.dart';

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
    Future<void> Function(AppUserProfile currentUser, AppSession session)
    action,
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
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
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
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Scatta foto finale'),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Scegli dalla galleria'),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
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
    final yyyy = value.year.toString();
    final hh = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy alle $hh:$min';
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

          final report = snapshot.data;
          if (report == null) {
            return const Center(
              child: Text(
                'Report non disponibile o privo di coordinate valide.',
              ),
            );
          }

          final event = report.event;
          final currentUid = currentUser?.uid;
          final isEventCreator =
              event != null &&
              currentUid != null &&
              event.creator.uid == currentUid;
          final isCleaningOwner =
              report.cleaningOwner != null &&
              currentUid != null &&
              report.cleaningOwner!.uid == currentUid;
          final joinedEvent = event?.participants.any(
            (participant) => participant.uid == currentUid,
          );

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _StatusHeader(report: report),
                  const SizedBox(height: 16),
                  if (report.photoUrl != null)
                    _PhotoSection(
                      title: 'Foto segnalazione',
                      imageUrl: report.photoUrl!,
                    ),
                  if (report.cleanupPhotoUrl != null) ...[
                    const SizedBox(height: 16),
                    _PhotoSection(
                      title: 'Foto dopo la pulizia',
                      imageUrl: report.cleanupPhotoUrl!,
                    ),
                  ],
                  const SizedBox(height: 16),
                  _InfoCard(report: report),
                  if (event != null) ...[
                    const SizedBox(height: 16),
                    _EventCard(
                      event: event,
                      dateText: _formatDateTime(event.scheduledAt),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (report.status == TrashpotStatus.segnalata &&
                      event == null)
                    FilledButton.icon(
                      onPressed: _busy ? null : _startCleaning,
                      icon: const Icon(Icons.cleaning_services_outlined),
                      label: const Text('Iniziare a pulire'),
                    ),
                  if (report.status == TrashpotStatus.segnalata &&
                      event == null)
                    const SizedBox(height: 12),
                  if (report.status == TrashpotStatus.segnalata &&
                      event == null)
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _scheduleEvent,
                      icon: const Icon(Icons.event_outlined),
                      label: const Text('Schedulare un evento per pulire'),
                    ),
                  if (report.status == TrashpotStatus.eventoCreato &&
                      event != null &&
                      currentUid != null &&
                      joinedEvent != true)
                    FilledButton.icon(
                      onPressed: _busy ? null : _joinEvent,
                      icon: const Icon(Icons.group_add_outlined),
                      label: const Text('Partecipa'),
                    ),
                  if (report.status == TrashpotStatus.eventoCreato &&
                      isEventCreator) ...[
                    if (joinedEvent == true) const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _busy ? null : _startCleaning,
                      icon: const Icon(Icons.play_arrow_outlined),
                      label: const Text('Passa a pulizia in corso'),
                    ),
                  ],
                  if (report.status == TrashpotStatus.puliziaInCorso &&
                      isCleaningOwner) ...[
                    FilledButton.icon(
                      onPressed: _busy ? null : _completeCleaning,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Segna come ripulito e carica foto'),
                    ),
                  ],
                  if (report.status == TrashpotStatus.puliziaInCorso &&
                      !isCleaningOwner &&
                      report.cleaningOwner != null)
                    Text(
                      'Pulizia in corso da parte di ${report.cleaningOwner!.label}.',
                      style: Theme.of(context).textTheme.bodyMedium,
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

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.report});

  final TrashpotReport report;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Chip(label: Text(trashpotStatusLabel(report.status))),
          const SizedBox(height: 8),
          Text(
            report.title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (report.createdAt != null) ...[
            const SizedBox(height: 6),
            Text(
              'Creato il ${report.dateLabel}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhotoSection extends StatelessWidget {
  const _PhotoSection({required this.title, required this.imageUrl});

  final String title;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return ColoredBox(
                  color: cs.surfaceContainerHighest,
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return ColoredBox(
                  color: cs.surfaceContainerHighest,
                  child: Center(
                    child: Text(
                      'Immagine non disponibile',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.report});

  final TrashpotReport report;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dettagli', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Text(report.note ?? report.title),
          const SizedBox(height: 12),
          Text(report.address),
          const SizedBox(height: 8),
          Text(
            'Coordinate: ${report.lat.toStringAsFixed(6)}, ${report.lng.toStringAsFixed(6)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          if (report.cleaningOwner != null) ...[
            const SizedBox(height: 8),
            Text(
              'Pulizia assegnata a: ${report.cleaningOwner!.label}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Evento di pulizia',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Text('Creato da ${event.creator.label}'),
          const SizedBox(height: 4),
          Text(dateText),
          const SizedBox(height: 12),
          Text(
            'Partecipanti (${event.participants.length})',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          for (final participant in event.participants)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.person_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(participant.label)),
                  if (participant.email.isNotEmpty)
                    Text(
                      participant.email,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
