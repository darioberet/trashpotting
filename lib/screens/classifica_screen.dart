import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/leaderboard_entry.dart';
import '../repositories/leaderboard_repository.dart';
import '../state/app_session.dart';
import '../state/classifica_view_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';

class ClassificaScreen extends StatefulWidget {
  ClassificaScreen({super.key, LeaderboardRepository? repository})
    : _repository = repository ?? FirestoreLeaderboardRepository();

  final LeaderboardRepository _repository;

  @override
  State<ClassificaScreen> createState() => _ClassificaScreenState();
}

class _ClassificaScreenState extends State<ClassificaScreen> {
  late final ClassificaViewModel _viewModel;
  int _seenErrorToken = 0;

  @override
  void initState() {
    super.initState();
    _viewModel = ClassificaViewModel(repository: widget._repository);
    _viewModel.load();
  }

  Future<void> _reload() async {
    await _viewModel.load();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final session = AppSessionScope.watch(context);
    final currentUid = session.currentUserId;

    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        if (_viewModel.errorToken > _seenErrorToken &&
            _viewModel.lastError != null) {
          _seenErrorToken = _viewModel.errorToken;
          session.publishError(
            _viewModel.lastError!,
            fallback: _viewModel.lastErrorFallback,
          );
        }

        final entries = _viewModel.entries;
        final isLoading = _viewModel.loading && !_viewModel.loaded;
        final isEmpty = _viewModel.loaded && entries.isEmpty;
        final topEntries = (isLoading || isEmpty)
            ? const <LeaderboardEntry>[]
            : entries.take(3).toList();
        final restEntries = (isLoading || isEmpty)
            ? const <LeaderboardEntry>[]
            : entries.skip(3).toList();

        Widget content;
        if (isLoading) {
          content = const Center(child: CircularProgressIndicator());
        } else if (isEmpty) {
          content = LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: constraints.maxHeight,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: const BoxDecoration(
                          color: AppColors.greenLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.emoji_events_outlined,
                          size: 44,
                          color: AppColors.greenBrand,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Sii il primo a segnalare!',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'La classifica si aggiorna ad ogni segnalazione.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        } else if (restEntries.isEmpty) {
          // Il podio (primi 3) copre già tutti gli iscritti: niente riga
          // sotto, ma uno spazio bianco vuoto sembra rotto — meglio un
          // messaggio esplicito.
          content = LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: constraints.maxHeight,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: const BoxDecoration(
                            color: AppColors.greenLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.groups_outlined,
                            size: 34,
                            color: AppColors.greenBrand,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Il podio è al completo!',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Non ci sono ancora altri utenti in classifica.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        } else {
          content = ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: restEntries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = restEntries[i];
              return _RankRow(
                entry: r,
                reportCount: _viewModel.reportCountFor(r.uid),
                isCurrentUser: currentUid != null && r.uid == currentUid,
              );
            },
          );
        }

        return Column(
          children: [
            _ClassificaHeroHeader(
              loading: _viewModel.loading,
              topEntries: topEntries,
              viewModel: _viewModel,
            ),
            Expanded(
              child: RefreshIndicator(onRefresh: _reload, child: content),
            ),
          ],
        );
      },
    );
  }
}

/// Header hero verde (gradiente) con titolo, sottotitolo, toggle periodo
/// e podio dei primi 3 — riproduce l'header pieno del mockup Figma.
class _ClassificaHeroHeader extends StatelessWidget {
  const _ClassificaHeroHeader({
    required this.loading,
    required this.topEntries,
    required this.viewModel,
  });

  final bool loading;
  final List<LeaderboardEntry> topEntries;
  final ClassificaViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    // Il titolo "Classifica" è già mostrato dall'AppBar verde condivisa
    // (stessa meccanica di safe-area della tab Mappa): qui parte subito
    // il contenuto sotto, non serve altro spazio manuale in alto.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.greenBrand, AppColors.greenDark],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Top contributor del territorio',
            style: TextStyle(fontSize: 14, color: Colors.white.withAlpha(190)),
          ),
          if (loading) ...[
            const SizedBox(height: 12),
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          ],
          if (topEntries.isNotEmpty) ...[
            const SizedBox(height: 20),
            _Podium(entries: topEntries, viewModel: viewModel),
          ],
        ],
      ),
    );
  }
}

/// Colori/asset medaglia per i primi 3 classificati.
class _MedalStyle {
  const _MedalStyle(this.color, this.asset);
  final Color color;
  final String asset;

  static const gold = _MedalStyle(
    Color(0xFFE8B23D),
    'assets/icons/medal_gold.svg',
  );
  static const silver = _MedalStyle(
    Color(0xFFB9BDC4),
    'assets/icons/medal_silver.svg',
  );
  static const bronze = _MedalStyle(
    Color(0xFFCE8A4E),
    'assets/icons/medal_bronze.svg',
  );

  static _MedalStyle forRank(int rank) => switch (rank) {
    1 => gold,
    2 => silver,
    _ => bronze,
  };
}

String _initialsOf(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.name, this.radius = 18, this.ringColor});

  final String name;
  final double radius;
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: ringColor != null ? const EdgeInsets.all(3) : EdgeInsets.zero,
      decoration: ringColor != null
          ? BoxDecoration(color: ringColor, shape: BoxShape.circle)
          : null,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.greenLight,
        foregroundColor: AppColors.greenDark,
        child: Text(
          _initialsOf(name),
          style: TextStyle(
            fontSize: radius * 0.55,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.entries, required this.viewModel});

  final List<LeaderboardEntry> entries;
  final ClassificaViewModel viewModel;

  LeaderboardEntry? _at(int i) => i < entries.length ? entries[i] : null;

  @override
  Widget build(BuildContext context) {
    final first = _at(0);
    final second = _at(1);
    final third = _at(2);

    if (first == null) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (second != null) ...[
          _PodiumSlot(
            entry: second,
            avatarRadius: 26,
            topOffset: 20,
            reportCount: viewModel.reportCountFor(second.uid),
          ),
          const SizedBox(width: 12),
        ],
        _PodiumSlot(
          entry: first,
          avatarRadius: 32,
          topOffset: 0,
          reportCount: viewModel.reportCountFor(first.uid),
        ),
        if (third != null) ...[
          const SizedBox(width: 12),
          _PodiumSlot(
            entry: third,
            avatarRadius: 26,
            topOffset: 28,
            reportCount: viewModel.reportCountFor(third.uid),
          ),
        ],
      ],
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  const _PodiumSlot({
    required this.entry,
    required this.avatarRadius,
    required this.topOffset,
    required this.reportCount,
  });

  final LeaderboardEntry entry;
  final double avatarRadius;
  final double topOffset;
  final int? reportCount;

  @override
  Widget build(BuildContext context) {
    final medal = _MedalStyle.forRank(entry.rank);

    return Padding(
      padding: EdgeInsets.only(top: topOffset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 11),
                child: _InitialsAvatar(
                  name: entry.name,
                  radius: avatarRadius,
                  ringColor: medal.color,
                ),
              ),
              SvgPicture.asset(medal.asset, width: 24, height: 24),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: avatarRadius * 3.2,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              color: context.palette.surfaceWhite,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: context.palette.cardShadow,
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.palette.textPrimary,
                  ),
                ),
                Text(
                  '${entry.points} pt',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.greenBrand,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (reportCount != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    reportCount == 1
                        ? '1 segnalazione'
                        : '$reportCount segnalazioni',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: context.palette.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.entry,
    required this.reportCount,
    required this.isCurrentUser,
  });

  final LeaderboardEntry entry;
  final int? reportCount;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isCurrentUser
            ? context.palette.greenLight
            : context.palette.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: isCurrentUser
            ? const Border(
                left: BorderSide(color: AppColors.greenBrand, width: 3),
              )
            : null,
        boxShadow: isCurrentUser
            ? null
            : [
                BoxShadow(
                  color: context.palette.cardShadow,
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '${entry.rank}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.palette.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _InitialsAvatar(name: entry.name, radius: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isCurrentUser ? 'Tu' : entry.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.palette.textPrimary,
                  ),
                ),
                if (reportCount != null)
                  Text(
                    reportCount == 1
                        ? '1 segnalazione'
                        : '$reportCount segnalazioni',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.palette.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${entry.points} pt',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.greenBrand,
            ),
          ),
        ],
      ),
    );
  }
}
