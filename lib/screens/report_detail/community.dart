part of '../report_detail_screen.dart';

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

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.joined,
    required this.currentUid,
  });

  final CleanupEvent event;
  final bool joined;
  final String? currentUid;

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
          const SizedBox(height: 10),
          // La card mostra solo i primi avatar: toccando la riga si apre
          // l'elenco completo (i nomi sono già nel documento, niente letture).
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: people.isEmpty
                  ? null
                  : () => _showParticipants(context, event, currentUid),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
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
                    if (people.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      const Text(
                        'Vedi tutti',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.bluePin,
                        ),
                      ),
                      const Icon(
                        AppIcons.chevronRight,
                        size: 16,
                        color: AppColors.bluePin,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Elenco completo dei partecipanti: chi organizza in cima, tu evidenziato.
void _showParticipants(
  BuildContext context,
  CleanupEvent event,
  String? currentUid,
) {
  final creatorUid = event.creator.uid;
  final people = [
    ...event.participants.where((p) => p.uid == creatorUid),
    ...event.participants.where((p) => p.uid != creatorUid),
  ];
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: people.length > 6 ? 0.7 : 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Partecipanti (${people.length})',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: ListView.separated(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: people.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final p = people[i];
                final isMe = p.uid == currentUid;
                final isCreator = p.uid == creatorUid;
                return Semantics(
                  label: [
                    isMe ? 'Tu, ${p.label}' : p.label,
                    if (isCreator) 'organizza',
                  ].join(', '),
                  excludeSemantics: true,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: isMe
                          ? Border.all(color: AppColors.yellow, width: 2)
                          : null,
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.mintBorder,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        UserAvatar(name: p.label, seed: p.uid),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isMe ? 'Tu, ${p.label}' : p.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (isCreator)
                          Container(
                            height: 24,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.blueLight,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Organizza',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.blueText,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
