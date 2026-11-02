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
import '../routes.dart';
import '../services/location_service.dart';
import '../services/media_picker_service.dart';
import '../services/photo_upload_service.dart';
import '../state/app_session.dart';
import '../state/report_detail_view_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../widgets/app_button.dart';
import '../widgets/image_source_bottom_sheet.dart';
import '../widgets/moderation_actions.dart';
import '../widgets/tab_header.dart';
import '../widgets/user_avatar.dart';
import '../theme/app_icons.dart';

// I blocchi della pagina stanno in report_detail/: foto, card, timeline,
// community (voto ed evento), azioni e mini mappa.
part 'report_detail/header.dart';
part 'report_detail/cards.dart';
part 'report_detail/timeline.dart';
part 'report_detail/community.dart';
part 'report_detail/actions.dart';

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
  GpsPosition? _userPosition;
  late final ReportDetailViewModel _vm = ReportDetailViewModel(
    reportId: widget.reportId,
    repository: widget._repository,
    photoUploadService: widget._photoUploadService,
  );
  final _moderation = ModerationRepository();

  // Memorizzato: ricrearlo a ogni build riaprirebbe l'ascolto su Firestore.
  late final Stream<TrashpotReport?> _reportStream = widget._repository
      .watchReport(widget.reportId);

  bool get _busy => _vm.busy;
  bool get _voting => _vm.voting;
  CommunityVote? get _myVote => _vm.myVote;
  String? get _reporterLabel => _vm.reporterLabel;

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
    _vm.addListener(_onViewModelChanged);
    // Solo per calcolare la distanza mostrata sulla foto: se fallisce
    // (permessi negati, GPS spento) la chip di distanza resta nascosta.
    LocationService()
        .getCurrentPosition()
        .then((p) {
          if (mounted) setState(() => _userPosition = p);
        })
        .catchError((_) {});
  }

  void _onViewModelChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _vm.removeListener(_onViewModelChanged);
    _vm.dispose();
    super.dispose();
  }

  void _maybeLoadMyVote(String? uid) => _vm.loadMyVote(uid);

  void _maybeLoadReporter(String? uid) => _vm.loadReporter(uid);

  Future<void> _vote(CommunityVote vote, AppSession session) async {
    final profile = session.currentProfile;
    final pos = _userPosition;
    if (profile == null || pos == null) return;
    try {
      final message = await _vm.vote(
        vote: vote,
        voter: profile,
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
      if (message == null || !mounted) return;
      unawaited(HapticFeedback.lightImpact());
      session.publishInfo(message);
    } catch (e) {
      if (!mounted) return;
      session.publishError(e, fallback: 'Voto non registrato.');
    }
  }

  void _share(TrashpotReport report) {
    Share.share(
      'Segnalazione Trashpotting — ${report.status.label}\n'
      '${report.title}\n${report.address}\n'
      'https://www.google.com/maps/search/?api=1&query=${report.lat},${report.lng}',
    );
  }

  /// Esegue un'azione del view model con l'utente corrente e mostra il
  /// messaggio di esito.
  Future<void> _runAction(
    Future<String?> Function(AppUserProfile currentUser) action,
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
    try {
      final message = await action(profile);
      if (message == null || !mounted) return;
      unawaited(HapticFeedback.lightImpact());
      session.publishInfo(message);
    } catch (e) {
      if (!mounted) return;
      session.publishError(e, fallback: 'Operazione non riuscita.');
    }
  }

  Future<void> _startCleaning() => _runAction(_vm.startCleaning);

  Future<void> _joinEvent() => _runAction(_vm.joinEvent);

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

    await _runAction((user) => _vm.scheduleEvent(user, scheduledAt));
  }

  Future<void> _completeCleaning() async {
    final source = await showImageSourceBottomSheet(
      context,
      cameraLabel: 'Scatta foto finale',
    );
    if (source == null || !mounted) return;

    final path = await widget._mediaPickerService.pickImagePath(source);
    if (path == null || !mounted) return;

    await _runAction((user) => _vm.completeCleaning(user, path));
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
        final isCleaned = status.isCleaned;
        final toClean = status.isToClean;

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
                                        fontSize: 22,
                                        height: 28 / 22,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.2,
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
                                      currentUid: currentUid,
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
