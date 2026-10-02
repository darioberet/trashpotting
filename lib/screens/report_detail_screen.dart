import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../core/geo_utils.dart';
import '../core/map_style.dart';
import '../core/marker_icons.dart';
import '../models/app_user_profile.dart';
import '../models/trashpot_report.dart';
import '../repositories/leaderboard_repository.dart';
import '../repositories/moderation_repository.dart';
import '../repositories/report_repository.dart';
import '../repositories/user_profile_repository.dart';
import '../routes.dart';
import '../services/location_service.dart';
import '../services/media_picker_service.dart';
import '../services/photo_upload_service.dart';
import '../state/app_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../widgets/image_source_bottom_sheet.dart';
import '../widgets/moderation_actions.dart';

class ReportDetailScreen extends StatefulWidget {
  ReportDetailScreen({
    super.key,
    required this.reportId,
    ReportRepository? repository,
    MediaPickerService? mediaPickerService,
    PhotoUploadService? photoUploadService,
    LeaderboardRepository? leaderboardRepository,
  }) : _repository = repository ?? FirestoreReportRepository(),
       _mediaPickerService = mediaPickerService ?? MediaPickerService(),
       _photoUploadService = photoUploadService ?? PhotoUploadService(),
       _leaderboardRepository =
           leaderboardRepository ?? FirestoreLeaderboardRepository();

  final String reportId;
  final ReportRepository _repository;
  final MediaPickerService _mediaPickerService;
  final PhotoUploadService _photoUploadService;
  final LeaderboardRepository _leaderboardRepository;

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  bool _busy = false;
  GpsPosition? _userPosition;
  final _userProfileRepository = UserProfileRepository();
  final _moderation = ModerationRepository();
  String? _reporterLabel;
  String? _loadedReporterForUid;

  static bool get _mapAvailable {
    if (kIsWeb) return true;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      default:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();
    // Solo per calcolare la distanza mostrata sulla foto: se fallisce
    // (permessi negati, GPS spento) la chip di distanza resta nascosta.
    LocationService()
        .getCurrentPosition()
        .then((p) {
          if (mounted) setState(() => _userPosition = p);
        })
        .catchError((_) {});
  }

  CommunityVote? _myVote;
  bool _voteLoaded = false;
  bool _voting = false;

  void _maybeLoadMyVote(String? uid) {
    if (uid == null || _voteLoaded) return;
    _voteLoaded = true;
    widget._repository
        .myVote(reportId: widget.reportId, uid: uid)
        .then((v) {
          if (mounted) setState(() => _myVote = v);
        })
        .catchError((_) {});
  }

  Future<void> _vote(CommunityVote vote, AppSession session) async {
    final profile = session.currentProfile;
    final pos = _userPosition;
    if (profile == null || pos == null || _voting) return;
    setState(() => _voting = true);
    try {
      await widget._repository.vote(
        reportId: widget.reportId,
        voter: profile,
        vote: vote,
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
      if (!mounted) return;
      setState(() => _myVote = vote);
      session.publishInfo(
        vote == CommunityVote.present
            ? 'Grazie! Hai confermato la segnalazione (+$pointsPerVote punto).'
            : 'Grazie per l\'aggiornamento (+$pointsPerVote punto).',
      );
    } catch (e) {
      if (!mounted) return;
      session.publishError(e, fallback: 'Voto non registrato.');
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  void _maybeLoadReporter(String? uid) {
    if (uid == null || _loadedReporterForUid == uid) return;
    _loadedReporterForUid = uid;
    _userProfileRepository
        .fetchProfile(uid)
        .then((profile) {
          if (mounted) setState(() => _reporterLabel = profile?.label);
        })
        .catchError((_) {});
  }

  void _share(TrashpotReport report) {
    Share.share(
      'Segnalazione Trashpotting — ${trashpotStatusLabel(report.status)}\n'
      '${report.title}\n${report.address}\n'
      'https://www.google.com/maps/search/?api=1&query=${report.lat},${report.lng}',
    );
  }

  Future<void> _runAction(
    Future<void> Function(AppUserProfile currentUser, AppSession session)
    action,
  ) async {
    if (_busy) return;
    final session = AppSessionScope.of(context);
    final profile = session.currentProfile;
    if (profile == null) {
      session.publishError(
        StateError('Utente non autenticato.'),
        fallback: 'Devi effettuare il login per modificare il report.',
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await action(profile, session);
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
    // Scegliendo oggi il calendario non impedisce un orario già passato.
    if (!scheduledAt.isAfter(DateTime.now())) {
      AppSessionScope.of(
        context,
      ).publishInfo('Scegli un orario futuro per l\'evento.');
      return;
    }

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

      // La pulizia è già registrata: un errore sui punti non deve farla
      // sembrare fallita all'utente.
      try {
        await widget._leaderboardRepository.incrementPoints(
          uid: currentUser.uid,
          username: currentUser.label,
          amount: pointsPerCleanup,
        );
      } catch (e) {
        debugPrint('incrementPoints dopo pulizia non riuscito: $e');
      }

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

    return StreamBuilder<TrashpotReport?>(
      stream: widget._repository.watchReport(widget.reportId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
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
            ),
          );
        }

        final report = snapshot.data;
        if (report == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
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
            ),
          );
        }

        _maybeLoadReporter(report.reporterUid);
        _maybeLoadMyVote(currentUser?.uid);
        final distanceMeters = _userPosition == null
            ? null
            : haversineKm(
                    _userPosition!.latitude,
                    _userPosition!.longitude,
                    report.lat,
                    report.lng,
                  ) *
                  1000;

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
        final joinedEvent = event?.participants.any((p) => p.uid == currentUid);
        final distanceText = _userPosition == null
            ? null
            : distanceLabel(
                haversineKm(
                  _userPosition!.latitude,
                  _userPosition!.longitude,
                  report.lat,
                  report.lng,
                ),
              );

        // Stessa meccanica di safe-area delle altre tab (Mappa/Classifica/
        // Profilo): una vera AppBar, posizionata da Scaffold in modo
        // affidabile sotto la status bar, invece di bottoni circolari
        // fluttuanti calcolati a mano sopra una foto full-bleed.
        return Scaffold(
          // Niente titolo qui: il titolo grande è già nel corpo, sotto la
          // foto (come nel mockup) — ripeterlo nell'AppBar è ridondante.
          appBar: AppBar(
            actions: [
              IconButton(
                icon: const Icon(Icons.ios_share_outlined),
                tooltip: 'Condividi',
                onPressed: () => _share(report),
              ),
              _ReportMenu(
                report: report,
                isAdmin: session.isAdmin,
                isOwn: report.reporterUid == session.currentUserId,
                moderation: _moderation,
              ),
            ],
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        // Photo header
                        if (report.photoUrl != null)
                          _PhotoHeader(
                            imageUrl: report.photoUrl!,
                            status: report.status,
                            typeLabel: report.typeLabel,
                            distanceText: distanceText,
                          ),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (report.photoUrl == null)
                                _StatusChipInline(status: report.status),

                              Text(
                                report.title,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w500,
                                      color: context.palette.textPrimary,
                                    ),
                              ),
                              const SizedBox(height: 12),

                              // Info rows
                              _InfoRow(
                                icon: Icons.place_outlined,
                                text: report.address,
                              ),
                              if (report.photoUrl == null &&
                                  report.typeLabel != null) ...[
                                const SizedBox(height: 6),
                                _InfoRow(
                                  icon: Icons.delete_outline,
                                  text: report.typeLabel!,
                                ),
                              ],
                              const SizedBox(height: 8),
                              _MetaRow(
                                status: report.status,
                                dateLabel: report.dateLabel,
                                reporterLabel: _reporterLabel,
                              ),
                              const SizedBox(height: 12),
                              Divider(
                                color: context.palette.divider,
                                thickness: 0.5,
                                height: 1,
                              ),
                              const SizedBox(height: 16),
                              _StatusStepper(status: report.status),
                              const SizedBox(height: 16),
                              Divider(
                                color: context.palette.divider,
                                thickness: 0.5,
                                height: 1,
                              ),
                              const SizedBox(height: 12),

                              if (report.note != null) ...[
                                Text(
                                  'Descrizione',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: context.palette.textPrimary,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  report.note!,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        fontSize: 13,
                                        color: context.palette.textSecondary,
                                        height: 1.6,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                Divider(
                                  color: context.palette.divider,
                                  thickness: 0.5,
                                  height: 1,
                                ),
                                const SizedBox(height: 12),
                              ],

                              if ((report.status == TrashpotStatus.segnalata ||
                                      report.status == TrashpotStatus.aperta) &&
                                  currentUser != null &&
                                  report.reporterUid != currentUser.uid) ...[
                                _CommunityVoteCard(
                                  report: report,
                                  myVote: _myVote,
                                  distanceMeters: distanceMeters,
                                  busy: _voting,
                                  onVote: (v) => _vote(v, session),
                                ),
                                const SizedBox(height: 16),
                              ],
                              if (report.status == TrashpotStatus.sparita) ...[
                                const _InfoRow(
                                  icon: Icons.help_outline,
                                  text:
                                      'Più persone sul posto hanno indicato '
                                      'che questo rifiuto non c\'è più.',
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Cleanup photo
                              Text(
                                'Foto dopo la pulizia',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: context.palette.textPrimary,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              if (report.cleanupPhotoUrl != null)
                                _PhotoSection(imageUrl: report.cleanupPhotoUrl!)
                              else
                                Container(
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: context.palette.surfaceWarm,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: context.palette.divider,
                                      width: 0.5,
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Nessuna foto ancora caricata',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: context.palette.textDisabled,
                                    ),
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
                                  report.status ==
                                      TrashpotStatus.puliziaInCorso &&
                                  !isCleaningOwner) ...[
                                const SizedBox(height: 12),
                                _InfoRow(
                                  icon: Icons.person_outline,
                                  text:
                                      'Pulizia in corso da parte di ${report.cleaningOwner!.label}.',
                                ),
                              ],

                              if (_mapAvailable) ...[
                                const SizedBox(height: 16),
                                _MiniMap(lat: report.lat, lng: report.lng),
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
          ),
        );
      },
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _PhotoHeader extends StatelessWidget {
  const _PhotoHeader({
    required this.imageUrl,
    required this.status,
    this.typeLabel,
    this.distanceText,
  });

  final String imageUrl;
  final TrashpotStatus status;
  final String? typeLabel;
  final String? distanceText;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => _openPhotoFullscreen(context, imageUrl),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        child: SizedBox(
          height: 220,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image(
                image: CachedNetworkImageProvider(imageUrl),
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
                  child: Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      size: 40,
                      color: context.palette.textDisabled,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 72,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withAlpha(0),
                        Colors.black.withAlpha(90),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StatusChipInline(status: status),
                    if (typeLabel != null || distanceText != null) ...[
                      const SizedBox(height: 8),
                      _TypeDistanceChip(
                        typeLabel: typeLabel,
                        distanceText: distanceText,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeDistanceChip extends StatelessWidget {
  const _TypeDistanceChip({this.typeLabel, this.distanceText});

  final String? typeLabel;
  final String? distanceText;

  @override
  Widget build(BuildContext context) {
    // Chip bianco sopra la foto: colori fissi del tema chiaro, non la
    // palette, altrimenti in modalità scura il testo diventa chiaro su bianco.
    final palette = AppPalette.light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(230),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (typeLabel != null) ...[
            const Icon(
              Icons.eco_outlined,
              size: 13,
              color: AppColors.greenDark,
            ),
            const SizedBox(width: 4),
            Text(
              typeLabel!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
              ),
            ),
          ],
          if (typeLabel != null && distanceText != null) ...[
            const SizedBox(width: 8),
            Container(width: 1, height: 10, color: palette.divider),
            const SizedBox(width: 8),
          ],
          if (distanceText != null) ...[
            Icon(Icons.place_outlined, size: 13, color: palette.textSecondary),
            const SizedBox(width: 3),
            Text(
              distanceText!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "È ancora lì?": chi passa vicino conferma o smentisce la segnalazione.
class _CommunityVoteCard extends StatelessWidget {
  const _CommunityVoteCard({
    required this.report,
    required this.myVote,
    required this.distanceMeters,
    required this.busy,
    required this.onVote,
  });

  final TrashpotReport report;
  final CommunityVote? myVote;
  final double? distanceMeters;
  final bool busy;
  final ValueChanged<CommunityVote> onVote;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final near = distanceMeters != null && distanceMeters! <= voteRadiusMeters;
    final confirmations = report.confirmations;

    final String subtitle;
    if (myVote == CommunityVote.present) {
      subtitle = 'Hai confermato che il rifiuto è ancora lì. Grazie!';
    } else if (myVote == CommunityVote.gone) {
      subtitle = 'Hai indicato che il rifiuto non c\'è più. Grazie!';
    } else if (distanceMeters == null) {
      subtitle = 'Attendi la posizione GPS per poter rispondere.';
    } else if (!near) {
      subtitle =
          'Avvicinati per rispondere: devi essere entro '
          '${voteRadiusMeters.round()} m (ora sei a '
          '${distanceLabel(distanceMeters! / 1000)}).';
    } else {
      subtitle = 'Sei qui vicino: aiuta gli altri a sapere se c\'è ancora.';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surfaceWarm,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.how_to_vote_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'È ancora lì?',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              if (confirmations > 0)
                Text(
                  confirmations == 1
                      ? 'Confermata da 1 persona'
                      : 'Confermata da $confirmations persone',
                  style: TextStyle(fontSize: 12, color: palette.textSecondary),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: palette.textSecondary),
          ),
          if (myVote == null && near) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () => onVote(CommunityVote.present),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('C\'è ancora'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : () => onVote(CommunityVote.gone),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Non c\'è più'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

enum _ReportMenuAction { flag, remove, blockAuthor }

/// Menu ⋮ del dettaglio: "Segnala contenuto" per tutti (non sulle proprie
/// segnalazioni), azioni di moderazione per gli admin.
class _ReportMenu extends StatelessWidget {
  const _ReportMenu({
    required this.report,
    required this.isAdmin,
    required this.isOwn,
    required this.moderation,
  });

  final TrashpotReport report;
  final bool isAdmin;
  final bool isOwn;
  final ModerationRepository moderation;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    final authorUid = report.reporterUid;
    final items = <PopupMenuEntry<_ReportMenuAction>>[
      if (!isOwn)
        const PopupMenuItem(
          value: _ReportMenuAction.flag,
          child: ListTile(
            leading: Icon(Icons.flag_outlined),
            title: Text('Segnala contenuto'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      if (isAdmin) ...[
        if (!isOwn) const PopupMenuDivider(),
        PopupMenuItem(
          value: _ReportMenuAction.remove,
          child: ListTile(
            leading: Icon(Icons.delete_outline, color: error),
            title: Text('Rimuovi segnalazione', style: TextStyle(color: error)),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (authorUid != null && !isOwn)
          PopupMenuItem(
            value: _ReportMenuAction.blockAuthor,
            child: ListTile(
              leading: Icon(Icons.block, color: error),
              title: Text('Blocca autore', style: TextStyle(color: error)),
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
    ];
    if (items.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<_ReportMenuAction>(
      tooltip: 'Altre azioni',
      itemBuilder: (_) => items,
      onSelected: (action) async {
        switch (action) {
          case _ReportMenuAction.flag:
            await showFlagReportDialog(
              context,
              moderation: moderation,
              report: report,
            );
          case _ReportMenuAction.remove:
            final removed = await confirmRemoveReport(
              context,
              moderation: moderation,
              reportId: report.id,
            );
            if (removed && context.mounted && context.canPop()) context.pop();
          case _ReportMenuAction.blockAuthor:
            await confirmBlockUser(
              context,
              moderation: moderation,
              uid: authorUid!,
            );
        }
      },
    );
  }
}

class _MiniMap extends StatelessWidget {
  const _MiniMap({required this.lat, required this.lng});

  final double lat;
  final double lng;

  @override
  Widget build(BuildContext context) {
    final position = LatLng(lat, lng);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 120,
        child: AbsorbPointer(
          child: FutureBuilder<BitmapDescriptor>(
            future: MarkerIconFactory.pin(
              color: AppColors.greenBrand,
              icon: Icons.eco,
            ),
            builder: (context, snapshot) {
              final icon = snapshot.data ?? BitmapDescriptor.defaultMarker;
              return GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: position,
                  zoom: 15,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('report'),
                    position: position,
                    icon: icon,
                  ),
                },
                style: mapStyleJson,
                liteModeEnabled: true,
                zoomControlsEnabled: false,
                zoomGesturesEnabled: false,
                scrollGesturesEnabled: false,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
                myLocationButtonEnabled: false,
              );
            },
          ),
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

class _StatusStepper extends StatelessWidget {
  const _StatusStepper({required this.status});

  final TrashpotStatus status;

  static const _stages = ['Segnalata', 'Aperta', 'In lavorazione', 'Pulita'];

  int get _activeIndex => switch (status) {
    TrashpotStatus.segnalata => 0,
    TrashpotStatus.aperta => 1,
    TrashpotStatus.inLavorazione ||
    TrashpotStatus.puliziaInCorso ||
    TrashpotStatus.eventoCreato => 2,
    TrashpotStatus.pulita || TrashpotStatus.ripulita => 3,
    TrashpotStatus.sparita => 0,
  };

  @override
  Widget build(BuildContext context) {
    final active = _activeIndex;
    return Row(
      children: [
        for (final (i, label) in _stages.indexed) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                color: i <= active
                    ? AppColors.greenBrand
                    : context.palette.divider,
              ),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (i == active)
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.greenBrand,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.greenLight, width: 3),
                  ),
                  child: const Icon(Icons.circle, size: 6, color: Colors.white),
                )
              else if (i == 0)
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: i < active
                          ? AppColors.greenBrand
                          : context.palette.textDisabled,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.flag_outlined,
                    size: 13,
                    color: i < active
                        ? AppColors.greenBrand
                        : context.palette.textDisabled,
                  ),
                )
              else
                Icon(
                  i < active ? Icons.check_circle : Icons.circle_outlined,
                  size: 18,
                  color: i < active
                      ? AppColors.greenBrand
                      : context.palette.textDisabled,
                ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: i == active ? FontWeight.w600 : FontWeight.normal,
                  color: i <= active
                      ? context.palette.textPrimary
                      : context.palette.textDisabled,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Riga "● Aperta | 📅 data | 👤 segnalante", come nel mockup — il nome del
/// segnalante è dato reale (profilo Firestore per [TrashpotReport.reporterUid]),
/// omesso se non disponibile o non ancora caricato.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.status, this.dateLabel, this.reporterLabel});

  final TrashpotStatus status;
  final String? dateLabel;
  final String? reporterLabel;

  @override
  Widget build(BuildContext context) {
    final dotColor = AppColors.statusChip(status).fg;

    final items = <Widget>[
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            trashpotStatusLabel(status),
            style: TextStyle(
              fontSize: 13,
              color: context.palette.textSecondary,
            ),
          ),
        ],
      ),
      if (dateLabel != null)
        _InfoRow(
          icon: Icons.calendar_today_outlined,
          text: dateLabel!,
          compact: true,
        ),
      if (reporterLabel != null)
        _InfoRow(
          icon: Icons.person_outline,
          text: reporterLabel!,
          compact: true,
        ),
    ];

    return Wrap(
      spacing: 14,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (i, item) in items.indexed) ...[
          if (i > 0)
            Container(width: 1, height: 12, color: context.palette.divider),
          item,
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
    this.compact = false,
  });

  final IconData icon;
  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        fontSize: 13,
        color: context.palette.textSecondary,
      ),
    );
    return Row(
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: context.palette.textSecondary),
        const SizedBox(width: 6),
        compact ? label : Expanded(child: label),
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
          child: Image(
            image: CachedNetworkImageProvider(imageUrl),
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
                child: Text(
                  'Immagine non disponibile',
                  style: TextStyle(fontSize: 13),
                ),
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
        color: context.palette.greenLight,
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
              color: (Theme.of(context).brightness == Brightness.dark
                  ? AppColors.greenBrand
                  : AppColors.greenDark),
            ),
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.person_outline,
            text: 'Creato da ${event.creator.label}',
          ),
          const SizedBox(height: 4),
          _InfoRow(icon: Icons.calendar_today_outlined, text: dateText),
          if (event.participants.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Partecipanti (${event.participants.length})',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: (Theme.of(context).brightness == Brightness.dark
                    ? AppColors.greenBrand
                    : AppColors.greenDark),
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
          child: Image(
            image: CachedNetworkImageProvider(imageUrl),
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Text(
                'Immagine non disponibile',
                style: TextStyle(color: Colors.white),
              ),
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
        border: Border(
          top: BorderSide(color: context.palette.divider, width: 0.5),
        ),
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
          if (s == TrashpotStatus.eventoCreato &&
              event != null &&
              currentUid != null &&
              joinedEvent != true)
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
