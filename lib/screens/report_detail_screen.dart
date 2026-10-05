import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../core/geo_utils.dart';
import '../core/map_style.dart';
import '../core/marker_icons.dart';
import '../core/time_format.dart';
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
import '../widgets/app_button.dart';
import '../widgets/image_source_bottom_sheet.dart';
import '../widgets/moderation_actions.dart';
import '../widgets/tab_header.dart';
import '../theme/app_icons.dart';

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

  // Memorizzato: ricrearlo a ogni build riaprirebbe l'ascolto su Firestore.
  late final Stream<TrashpotReport?> _reportStream = widget._repository
      .watchReport(widget.reportId);
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
      unawaited(HapticFeedback.lightImpact());
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
      unawaited(HapticFeedback.lightImpact());
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

  @override
  Widget build(BuildContext context) {
    final session = AppSessionScope.watch(context);
    final currentUser = session.currentUser;

    return StreamBuilder<TrashpotReport?>(
      stream: _reportStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const _DetailMessage(
            icon: AppIcons.offline,
            message: 'Errore di rete. Controlla la connessione.',
          );
        }

        final report = snapshot.data;
        if (report == null) {
          return const _DetailMessage(
            icon: AppIcons.delete,
            message: 'Segnalazione non disponibile o eliminata.',
          );
        }

        _maybeLoadReporter(report.reporterUid);
        _maybeLoadMyVote(currentUser?.uid);
        final distanceKm = _userPosition == null
            ? null
            : haversineKm(
                _userPosition!.latitude,
                _userPosition!.longitude,
                report.lat,
                report.lng,
              );

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
        final joinedEvent =
            event?.participants.any((p) => p.uid == currentUid) ?? false;
        final status = report.status;
        final isCleaned =
            status == TrashpotStatus.pulita ||
            status == TrashpotStatus.ripulita;
        final toClean =
            status == TrashpotStatus.segnalata ||
            status == TrashpotStatus.aperta;

        final topInset = MediaQuery.of(context).padding.top;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
          ),
          child: Scaffold(
            body: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Stack(
                          children: [
                            _PhotoHeader(report: report, topInset: topInset),
                            // Il foglio dei contenuti sale sulla foto con
                            // gli angoli arrotondati.
                            Container(
                              margin: const EdgeInsets.only(
                                top: _PhotoHeader.height - 30,
                              ),
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                22,
                                16,
                                24,
                              ),
                              decoration: const BoxDecoration(
                                color: AppColors.bgAlt,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(28),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Semantics(
                                    header: true,
                                    child: Text(
                                      report.title,
                                      style: const TextStyle(
                                        fontSize: 26,
                                        height: 32 / 26,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.8,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  _InfoRow(
                                    icon: AppIcons.place,
                                    text: report.address,
                                  ),
                                  if (report.typeLabel != null) ...[
                                    const SizedBox(height: 4),
                                    _InfoRow(
                                      icon: AppIcons.forWasteType(
                                        report.typeLabel,
                                      ),
                                      text: report.typeLabel!,
                                    ),
                                  ],
                                  if (isCleaned &&
                                      report.cleaningOwner != null) ...[
                                    const SizedBox(height: 16),
                                    _CleanedByCard(report: report),
                                  ],
                                  const SizedBox(height: 16),
                                  _StatsRow(
                                    report: report,
                                    distanceKm: distanceKm,
                                    reporterLabel: _reporterLabel,
                                  ),
                                  const SizedBox(height: 22),
                                  _StatusTimeline(report: report),
                                  if (toClean &&
                                      currentUser != null &&
                                      report.reporterUid !=
                                          currentUser.uid) ...[
                                    const SizedBox(height: 20),
                                    _CommunityVoteCard(
                                      myVote: _myVote,
                                      distanceMeters: distanceKm == null
                                          ? null
                                          : distanceKm * 1000,
                                      busy: _voting,
                                      onVote: (v) => _vote(v, session),
                                    ),
                                  ],
                                  if (status == TrashpotStatus.sparita) ...[
                                    const SizedBox(height: 20),
                                    const _NoteCard(
                                      icon: AppIcons.hidden,
                                      bg: AppColors.greyLight,
                                      fg: AppColors.textSecondary,
                                      text:
                                          'Più persone sul posto hanno '
                                          'indicato che questo rifiuto non '
                                          'c\'è più.',
                                    ),
                                  ],
                                  if (event != null) ...[
                                    const SizedBox(height: 20),
                                    _EventCard(
                                      event: event,
                                      joined: joinedEvent,
                                    ),
                                  ],
                                  if (report.cleaningOwner != null &&
                                      status ==
                                          TrashpotStatus.puliziaInCorso) ...[
                                    const SizedBox(height: 20),
                                    _NoteCard(
                                      icon: AppIcons.clean,
                                      bg: AppColors.amberLight,
                                      fg: AppColors.amberText,
                                      text: isCleaningOwner
                                          ? 'Stai pulendo questa zona. '
                                                'Quando hai finito, scatta '
                                                'la foto finale.'
                                          : 'Pulizia in corso da parte di '
                                                '${report.cleaningOwner!.label}.',
                                    ),
                                  ],
                                  if (_mapAvailable) ...[
                                    const SizedBox(height: 20),
                                    _MiniMap(
                                      report: report,
                                      onOpenMap: () =>
                                          context.go(AppRoutes.mappa),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _BottomActions(
                      report: report,
                      busy: _busy,
                      isEventCreator: isEventCreator,
                      isCleaningOwner: isCleaningOwner,
                      joinedEvent: joinedEvent,
                      signedIn: currentUid != null,
                      onStartCleaning: _startCleaning,
                      onScheduleEvent: _scheduleEvent,
                      onJoinEvent: _joinEvent,
                      onCompleteCleaning: _completeCleaning,
                      onOpenMap: () => context.go(AppRoutes.mappa),
                    ),
                  ],
                ),

                // Pulsanti tondi fissi sopra la foto.
                Positioned(
                  left: 16,
                  right: 16,
                  top: topInset + 12,
                  child: Row(
                    children: [
                      HeaderCircleButton(
                        icon: AppIcons.back,
                        tooltip: 'Indietro',
                        onPressed: () => context.canPop()
                            ? context.pop()
                            : context.go(AppRoutes.mappa),
                      ),
                      const Spacer(),
                      HeaderCircleButton(
                        icon: AppIcons.share,
                        tooltip: 'Condividi',
                        onPressed: () => _share(report),
                      ),
                      const SizedBox(width: 8),
                      _ReportMenu(
                        report: report,
                        isAdmin: session.isAdmin,
                        isOwn: report.reporterUid == session.currentUserId,
                        moderation: _moderation,
                      ),
                    ],
                  ),
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
          ),
        );
      },
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

/// Errore o segnalazione non trovata, con il pulsante per tornare indietro.
class _DetailMessage extends StatelessWidget {
  const _DetailMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: context.palette.textSecondary),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              AppButton(
                label: 'Torna indietro',
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Foto in testa al dettaglio, a tutta larghezza sotto la status bar. Se la
/// zona è stata ripulita si scorre tra "Prima" e "Dopo" con il selettore.
class _PhotoHeader extends StatefulWidget {
  const _PhotoHeader({required this.report, required this.topInset});

  static const height = 330.0;

  final TrashpotReport report;
  final double topInset;

  @override
  State<_PhotoHeader> createState() => _PhotoHeaderState();
}

class _PhotoHeaderState extends State<_PhotoHeader> {
  final _controller = PageController();
  int _page = 0;

  List<({String label, String url, DateTime? date})> get _photos => [
    if (widget.report.photoUrl != null)
      (
        label: 'Prima',
        url: widget.report.photoUrl!,
        date: widget.report.createdAt,
      ),
    if (widget.report.cleanupPhotoUrl != null)
      (
        label: 'Dopo',
        url: widget.report.cleanupPhotoUrl!,
        date: widget.report.cleanedAt,
      ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = _photos;
    final (:bg, :fg) = AppColors.statusChip(widget.report.status);
    // Le etichette servono solo se c'è la foto "Dopo".
    final beforeAfter = widget.report.cleanupPhotoUrl != null;
    final current = photos.isEmpty
        ? null
        : photos[_page.clamp(0, photos.length - 1)];

    return SizedBox(
      height: _PhotoHeader.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photos.isEmpty)
            ColoredBox(
              color: bg,
              child: Icon(
                AppIcons.forWasteType(widget.report.typeLabel),
                size: 72,
                color: fg.withAlpha(120),
              ),
            )
          else
            PageView(
              controller: _controller,
              onPageChanged: (p) => setState(() => _page = p),
              children: [
                for (final photo in photos)
                  GestureDetector(
                    onTap: () => _openPhotoFullscreen(context, photo.url),
                    child: _HeaderImage(url: photo.url),
                  ),
              ],
            ),
          // Sfumature scure in alto (pulsanti, status bar) e in basso
          // (selettore, puntini).
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 120,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x7310231D), Color(0x0010231D)],
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 110,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x0010231D), Color(0x7310231D)],
                  ),
                ),
              ),
            ),
          ),
          if (beforeAfter && current != null) ...[
            Positioned(
              left: 16,
              top: widget.topInset + 72,
              child: IgnorePointer(
                child: _PhotoCaption(
                  text: current.date == null
                      ? current.label
                      : '${current.label}, ${shortDateLabel(current.date!)}',
                ),
              ),
            ),
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: _BeforeAfterToggle(
                  labels: [for (final p in photos) p.label],
                  selected: _page,
                  onSelected: (i) => _controller.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                  ),
                ),
              ),
            ),
          ] else if (photos.length > 1)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < photos.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: i == _page ? 18 : 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        decoration: BoxDecoration(
                          color: i == _page
                              ? Colors.white
                              : Colors.white.withAlpha(140),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PhotoCaption extends StatelessWidget {
  const _PhotoCaption({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withAlpha(140),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _HeaderImage extends StatelessWidget {
  const _HeaderImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Image(
      image: CachedNetworkImageProvider(url),
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return const ColoredBox(
          color: Color(0xFF3A3A36),
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        );
      },
      errorBuilder: (_, _, _) => const ColoredBox(
        color: Color(0xFF3A3A36),
        child: Center(
          child: Icon(AppIcons.imageBroken, size: 40, color: Colors.white54),
        ),
      ),
    );
  }
}

/// Selettore "Prima | Dopo" sopra la foto: colori fissi perché sta sempre
/// su un'immagine, in qualsiasi tema.
class _BeforeAfterToggle extends StatelessWidget {
  const _BeforeAfterToggle({
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withAlpha(140),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Semantics(
              button: true,
              selected: i == selected,
              label: 'Foto ${labels[i]}',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelected(i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 40,
                  constraints: const BoxConstraints(minWidth: 84),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: i == selected ? AppColors.greenDark : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Pulita da Dario": chi ha ripulito la zona, con i punti guadagnati.
class _CleanedByCard extends StatelessWidget {
  const _CleanedByCard({required this.report});

  final TrashpotReport report;

  @override
  Widget build(BuildContext context) {
    final name = report.cleaningOwner!.label;
    // Prima parte dell'indirizzo ("SS16" da "SS16, Ponte del Colombarone").
    final place = report.address.split(',').first.trim();
    return Container(
      padding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.greenBrand,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -34,
            top: -38,
            child: Icon(
              AppIcons.leaf,
              size: 110,
              color: Colors.white.withAlpha(36),
            ),
          ),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(41),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  name.characters.first.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pulita da $name',
                      style: const TextStyle(
                        fontSize: 17,
                        height: 22 / 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      place.isEmpty
                          ? 'Grazie! Questa zona è di nuovo pulita.'
                          : 'Grazie! $place è di nuovo pulita.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 18 / 13,
                        color: Colors.white.withAlpha(217),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Align(
                alignment: Alignment.topCenter,
                child: _PointsBadge(points: pointsPerCleanup),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pillola gialla "+N pt".
class _PointsBadge extends StatelessWidget {
  const _PointsBadge({required this.points, this.height = 26});

  final int points;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.only(left: 6, right: 8),
      decoration: BoxDecoration(
        color: AppColors.yellow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(AppIcons.starFilled, size: 12, color: AppColors.onYellow),
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
    );
  }
}

/// Tre riquadri: distanza, tempo (da quando è segnalata, o quanto ci è
/// voluto a pulirla) e conferme della community.
class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.report,
    required this.distanceKm,
    required this.reporterLabel,
  });

  final TrashpotReport report;
  final double? distanceKm;
  final String? reporterLabel;

  /// Durata in forma "numero + unità": 5 min, 2 ore, 3 giorni.
  static (String, String) _durationParts(Duration d) {
    if (d.inMinutes < 60) {
      final m = d.inMinutes.clamp(1, 59);
      return ('$m', 'min');
    }
    if (d.inHours < 24) {
      return ('${d.inHours}', d.inHours == 1 ? 'ora' : 'ore');
    }
    return ('${d.inDays}', d.inDays == 1 ? 'giorno' : 'giorni');
  }

  @override
  Widget build(BuildContext context) {
    final created = report.createdAt;
    final cleaned = report.cleanedAt;
    final tiles = <Widget>[];

    final km = distanceKm;
    if (km != null) {
      final label = distanceLabel(km);
      final i = label.lastIndexOf(' ');
      tiles.add(
        _StatTile(
          value: label.substring(0, i),
          unit: label.substring(i + 1),
          caption: 'da te',
          bg: AppColors.greenLight,
          fg: AppColors.greenDark,
        ),
      );
    }
    if (created != null) {
      final isCleaned = cleaned != null;
      final (value, unit) = _durationParts(
        (cleaned ?? DateTime.now()).difference(created),
      );
      tiles.add(
        _StatTile(
          value: value,
          unit: unit,
          caption: isCleaned
              ? 'per pulirla'
              : reporterLabel == null
              ? 'fa'
              : 'fa, da $reporterLabel',
          bg: AppColors.yellowLight,
          fg: AppColors.yellowText,
        ),
      );
    }
    tiles.add(
      _StatTile(
        value: '${report.confirmations}',
        caption: report.confirmations == 1 ? 'conferma' : 'conferme',
        bg: AppColors.purpleLight,
        fg: AppColors.purpleDark,
      ),
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, tile) in tiles.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: tile),
          ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.caption,
    required this.bg,
    required this.fg,
    this.unit,
  });

  final String value;
  final String? unit;
  final String caption;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: [value, ?unit, caption].join(' '),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      fontSize: 22,
                      height: 26 / 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (unit != null)
                    TextSpan(
                      text: ' $unit',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg),
            ),
            Text(
              caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 16 / 12,
                fontWeight: FontWeight.w600,
                color: fg.withAlpha(204),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Avanzamento in tre tappe: Da pulire → In corso → Pulita, con le date.
class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.report});

  final TrashpotReport report;

  /// Data della tappa: "oggi, 10:12", "ieri, 18:30" o "28 set".
  static String? _stepDate(DateTime? time) {
    if (time == null) return null;
    final now = DateTime.now();
    final days = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(time.year, time.month, time.day)).inDays;
    final hhmm =
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
    if (days == 0) return 'oggi, $hhmm';
    if (days == 1) return 'ieri, $hhmm';
    return shortDateLabel(time);
  }

  @override
  Widget build(BuildContext context) {
    final s = report.status;
    final current = switch (s) {
      TrashpotStatus.segnalata ||
      TrashpotStatus.aperta ||
      TrashpotStatus.sparita => 0,
      TrashpotStatus.inLavorazione ||
      TrashpotStatus.eventoCreato ||
      TrashpotStatus.puliziaInCorso => 1,
      TrashpotStatus.pulita || TrashpotStatus.ripulita => 2,
    };
    final event = report.event;
    final middleDate = s == TrashpotStatus.eventoCreato && event != null
        ? event.scheduledAt
        : report.cleaningStartedAt;
    final steps = [
      (
        label: current == 0 ? 'Da pulire' : 'Segnalata',
        date: _stepDate(report.createdAt),
        color: AppColors.statusColor(TrashpotStatus.segnalata),
        light: AppColors.redLight,
        text: AppColors.redText,
        icon: AppIcons.forWasteType(report.typeLabel),
      ),
      (
        label: s == TrashpotStatus.eventoCreato ? 'Evento' : 'In corso',
        date: current >= 1 ? _stepDate(middleDate) : null,
        color: s == TrashpotStatus.eventoCreato
            ? AppColors.bluePin
            : AppColors.amberDot,
        light: s == TrashpotStatus.eventoCreato
            ? AppColors.blueLight
            : AppColors.amberLight,
        text: s == TrashpotStatus.eventoCreato
            ? AppColors.blueText
            : AppColors.amberText,
        icon: s == TrashpotStatus.eventoCreato
            ? AppIcons.calendar
            : AppIcons.clean,
      ),
      (
        label: 'Pulita',
        date: current == 2 ? _stepDate(report.cleanedAt) : null,
        color: AppColors.greenPin,
        light: AppColors.greenStatusLight,
        text: AppColors.greenDark,
        icon: AppIcons.check,
      ),
    ];

    return Semantics(
      label: 'Stato: ${steps[current].label}',
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const stepWidth = 96.0;
          // La linea va dal centro della prima tappa a quello dell'ultima.
          final lineWidth = constraints.maxWidth + 32 - stepWidth;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: stepWidth / 2 - 16,
                top: 15,
                width: lineWidth,
                height: 3,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFECE6D9),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: current / 2,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.mint,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(-16, 0),
                child: SizedBox(
                  width: constraints.maxWidth + 32,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (i, step) in steps.indexed)
                        SizedBox(
                          width: stepWidth,
                          child: Column(
                            children: [
                              _TimelineDot(
                                done: i < current,
                                current: i == current,
                                color: step.color,
                                light: step.light,
                                icon: step.icon,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                step.label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 16 / 13,
                                  fontWeight: i == current
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: i == current
                                      ? step.text
                                      : i < current
                                      ? AppColors.textPrimary
                                      : AppColors.textDisabled,
                                ),
                              ),
                              if (step.date != null)
                                Text(
                                  step.date!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 16 / 12,
                                    color: AppColors.textDisabled,
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TimelineDot extends StatelessWidget {
  const _TimelineDot({
    required this.done,
    required this.current,
    required this.color,
    required this.light,
    required this.icon,
  });

  final bool done;
  final bool current;
  final Color color;
  final Color light;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (current) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: light, spreadRadius: 5)],
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      );
    }
    if (done) {
      return Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: AppColors.greenStatusLight,
          shape: BoxShape.circle,
        ),
        child: const Icon(AppIcons.check, size: 16, color: AppColors.greenDark),
      );
    }
    // Tappa futura: cerchio vuoto tratteggiato.
    return CustomPaint(
      size: const Size(32, 32),
      painter: _DashedCirclePainter(color: AppColors.mintBorder),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.greenLight.withAlpha(160),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rect = Offset.zero & size;
    const dashes = 12;
    const sweep = 2 * math.pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect.deflate(1), i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// "È ancora lì?": chi passa vicino conferma o smentisce la segnalazione.
class _CommunityVoteCard extends StatelessWidget {
  const _CommunityVoteCard({
    required this.myVote,
    required this.distanceMeters,
    required this.busy,
    required this.onVote,
  });

  final CommunityVote? myVote;
  final double? distanceMeters;
  final bool busy;
  final ValueChanged<CommunityVote> onVote;

  @override
  Widget build(BuildContext context) {
    final near = distanceMeters != null && distanceMeters! <= voteRadiusMeters;

    final String? hint;
    if (myVote != null) {
      hint = null;
    } else if (distanceMeters == null) {
      hint = 'Attendi la posizione GPS per poter rispondere.';
    } else if (!near) {
      hint =
          'Avvicinati per rispondere: devi essere entro '
          '${voteRadiusMeters.round()} m (ora sei a '
          '${distanceLabel(distanceMeters! / 1000)}).';
    } else {
      hint = null;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.purpleLight,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                AppIcons.usersGroup,
                size: 20,
                color: AppColors.purpleDark,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  header: true,
                  child: const Text(
                    'È ancora lì?',
                    style: TextStyle(
                      fontSize: 17,
                      height: 22 / 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: AppColors.purpleDark,
                    ),
                  ),
                ),
              ),
              const _PointsBadge(points: pointsPerVote, height: 22),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Se passi di qui, aiuta la community a tenere la mappa '
            'aggiornata.',
            style: TextStyle(
              fontSize: 14,
              height: 20 / 14,
              color: AppColors.purpleDark.withAlpha(217),
            ),
          ),
          const SizedBox(height: 14),
          if (myVote != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.greenStatusLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: AppColors.greenBrand,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      AppIcons.check,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      myVote == CommunityVote.present
                          ? 'Grazie! Hai confermato che è ancora lì.'
                          : 'Grazie! Se lo confermano altre persone, '
                                'sparisce dalla mappa.',
                      style: const TextStyle(
                        fontSize: 14,
                        height: 20 / 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.greenDark,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (near)
            Row(
              children: [
                Expanded(
                  child: _VoteButton(
                    label: 'Sì, è ancora lì',
                    icon: AppIcons.visible,
                    primary: true,
                    onPressed: busy
                        ? null
                        : () => onVote(CommunityVote.present),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _VoteButton(
                    label: 'Non c\'è più',
                    icon: AppIcons.hidden,
                    primary: false,
                    onPressed: busy ? null : () => onVote(CommunityVote.gone),
                  ),
                ),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  AppIcons.place,
                  size: 16,
                  color: AppColors.purpleDark,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hint!,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 18 / 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.purpleDark,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({
    required this.label,
    required this.icon,
    required this.primary,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? Colors.white : AppColors.purpleDark;
    return Material(
      color: primary ? AppColors.purple : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: fg,
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

/// Riquadro informativo colorato (sparita, pulizia in corso…).
class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.icon,
    required this.text,
    required this.bg,
    required this.fg,
  });

  final IconData icon;
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 20 / 14,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.joined});

  final CleanupEvent event;
  final bool joined;

  @override
  Widget build(BuildContext context) {
    final at = event.scheduledAt;
    final time =
        '${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}';
    final people = event.participants;
    const shown = 5;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.blueLight,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      shortDayLabel(at).split(' ').last.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: AppColors.bluePin,
                      ),
                    ),
                    Text(
                      '${at.day}',
                      style: const TextStyle(
                        fontSize: 22,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        color: AppColors.blueText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Evento di pulizia',
                      style: TextStyle(
                        fontSize: 17,
                        height: 22 / 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: AppColors.blueText,
                      ),
                    ),
                    Text(
                      '${shortDayLabel(at)} alle $time · '
                      'organizza ${event.creator.label}',
                      style: TextStyle(
                        fontSize: 13,
                        height: 18 / 13,
                        color: AppColors.blueText.withAlpha(217),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (people.isNotEmpty)
                SizedBox(
                  height: 32,
                  width: 32 + 22.0 * (math.min(people.length, shown) - 1),
                  child: Stack(
                    children: [
                      for (final (i, p) in people.take(shown).indexed)
                        Positioned(
                          left: 22.0 * i,
                          child: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.blueLight,
                                width: 2,
                              ),
                            ),
                            child: Text(
                              p.label.characters.first.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.blueText,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              if (people.isNotEmpty) const SizedBox(width: 10),
              Expanded(
                child: Text(
                  people.isEmpty
                      ? 'Ancora nessun partecipante: sii il primo!'
                      : people.length == 1
                      ? (joined ? 'Partecipi solo tu' : '1 partecipante')
                      : joined
                      ? 'Tu e altri ${people.length - 1}'
                      : '${people.length} partecipanti',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.blueText,
                  ),
                ),
              ),
            ],
          ),
        ],
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
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 20 / 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniMap extends StatelessWidget {
  const _MiniMap({required this.report, required this.onOpenMap});

  final TrashpotReport report;
  final VoidCallback onOpenMap;

  IconData get _icon => switch (report.status) {
    TrashpotStatus.segnalata ||
    TrashpotStatus.aperta ||
    TrashpotStatus.inLavorazione => AppIcons.forWasteType(report.typeLabel),
    TrashpotStatus.eventoCreato => AppIcons.markerEvent,
    TrashpotStatus.puliziaInCorso => AppIcons.markerCleaning,
    TrashpotStatus.pulita || TrashpotStatus.ripulita => AppIcons.markerCleaned,
    TrashpotStatus.sparita => AppIcons.markerGone,
  };

  @override
  Widget build(BuildContext context) {
    final position = LatLng(report.lat, report.lng);
    final color = AppColors.statusColor(report.status);
    return Container(
      height: 120,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFECE6D9)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AbsorbPointer(
            child: FutureBuilder<BitmapDescriptor>(
              future: MarkerIconFactory.pin(
                color: color,
                icon: _icon,
                iconColor: color == AppColors.amberDot
                    ? const Color(0xFF3A1A00)
                    : Colors.white,
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
                      anchor: snapshot.hasData
                          ? MarkerIconFactory.pinAnchor
                          : const Offset(0.5, 1),
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
          Positioned(
            right: 10,
            bottom: 10,
            child: Material(
              color: Colors.white,
              shape: const StadiumBorder(),
              elevation: 2,
              shadowColor: AppColors.textPrimary.withAlpha(60),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onOpenMap,
                child: const SizedBox(
                  height: 40,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          AppIcons.map,
                          size: 16,
                          color: AppColors.greenDark,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Apri su mappa',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.greenDark,
                          ),
                        ),
                      ],
                    ),
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

/// Barra in fondo con le azioni possibili nello stato attuale: la
/// principale gialla, quella secondaria bianca.
class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.report,
    required this.busy,
    required this.isEventCreator,
    required this.isCleaningOwner,
    required this.joinedEvent,
    required this.signedIn,
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
  final bool joinedEvent;
  final bool signedIn;
  final VoidCallback onStartCleaning;
  final VoidCallback onScheduleEvent;
  final VoidCallback onJoinEvent;
  final VoidCallback onCompleteCleaning;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final s = report.status;
    final event = report.event;
    final toClean = s == TrashpotStatus.segnalata || s == TrashpotStatus.aperta;

    final List<Widget> buttons;
    if (toClean && event == null && signedIn) {
      buttons = [
        AppButton(
          label: 'Crea evento',
          icon: AppIcons.calendar,
          variant: AppButtonVariant.secondary,
          height: 56,
          expand: false,
          onPressed: busy ? null : onScheduleEvent,
        ),
        Expanded(
          child: AppButton(
            label: 'Voglio pulire',
            icon: AppIcons.clean,
            badge: '+$pointsPerCleanup pt',
            height: 56,
            loading: busy,
            onPressed: onStartCleaning,
          ),
        ),
      ];
    } else if (s == TrashpotStatus.eventoCreato && isEventCreator) {
      buttons = [
        Expanded(
          child: AppButton(
            label: 'Inizia la pulizia',
            icon: AppIcons.start,
            height: 56,
            loading: busy,
            onPressed: onStartCleaning,
          ),
        ),
      ];
    } else if (s == TrashpotStatus.eventoCreato &&
        event != null &&
        signedIn &&
        !joinedEvent) {
      buttons = [
        Expanded(
          child: AppButton(
            label: 'Partecipa all\'evento',
            icon: AppIcons.joinGroup,
            height: 56,
            loading: busy,
            onPressed: onJoinEvent,
          ),
        ),
      ];
    } else if (s == TrashpotStatus.puliziaInCorso && isCleaningOwner) {
      buttons = [
        Expanded(
          child: AppButton(
            label: 'Segna come pulita',
            icon: AppIcons.camera,
            badge: '+$pointsPerCleanup pt',
            height: 56,
            loading: busy,
            onPressed: onCompleteCleaning,
          ),
        ),
      ];
    } else {
      buttons = [
        Expanded(
          child: AppButton(
            label: 'Apri su mappa',
            icon: AppIcons.map,
            variant: AppButtonVariant.secondary,
            height: 56,
            onPressed: onOpenMap,
          ),
        ),
      ];
    }

    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 18 + bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.greenLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          for (final (i, b) in buttons.indexed) ...[
            if (i > 0) const SizedBox(width: 10),
            b,
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
            leading: Icon(AppIcons.flag),
            title: Text('Segnala contenuto'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      if (isAdmin) ...[
        if (!isOwn) const PopupMenuDivider(),
        PopupMenuItem(
          value: _ReportMenuAction.remove,
          child: ListTile(
            leading: Icon(AppIcons.delete, color: error),
            title: Text('Rimuovi segnalazione', style: TextStyle(color: error)),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (authorUid != null && !isOwn)
          PopupMenuItem(
            value: _ReportMenuAction.blockAuthor,
            child: ListTile(
              leading: Icon(AppIcons.block, color: error),
              title: Text('Blocca autore', style: TextStyle(color: error)),
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
    ];
    if (items.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<_ReportMenuAction>(
      tooltip: 'Altre opzioni',
      padding: EdgeInsets.zero,
      // Stesso aspetto dei pulsanti tondi accanto; il tap lo gestisce il menu.
      child: IgnorePointer(
        child: HeaderCircleButton(
          icon: AppIcons.more,
          tooltip: 'Altre opzioni',
          onPressed: () {},
        ),
      ),
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
