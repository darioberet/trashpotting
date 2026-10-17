part of '../report_detail_screen.dart';

class _MiniMap extends StatelessWidget {
  const _MiniMap({required this.report, required this.onOpenMap});

  final TrashpotReport report;
  final VoidCallback onOpenMap;

  IconData get _icon => AppIcons.marker(report.status, report.typeLabel);

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
    final toClean = s.isToClean;

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
