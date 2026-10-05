import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/leaderboard_entry.dart';
import '../repositories/leaderboard_repository.dart';
import '../state/app_session.dart';
import '../state/classifica_view_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../widgets/skeleton.dart';
import '../widgets/tab_header.dart';
import '../widgets/user_avatar.dart';

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
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _viewModel = ClassificaViewModel(repository: widget._repository);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _viewModel.load(uid: AppSessionScope.of(context).currentUserId);
    }
  }

  Future<void> _reload() =>
      _viewModel.load(uid: AppSessionScope.of(context).currentUserId);

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSessionScope.watch(context);
    final currentUid = session.currentUserId;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: AnimatedBuilder(
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
          final top = entries.take(3).toList();
          final rest = entries.skip(3).toList();
          final me = _viewModel.me;
          final myName = session.username?.trim().isNotEmpty == true
              ? session.username!.trim()
              : 'Tu';
          final showMe = currentUid != null && me != null && !isEmpty;

          Widget content;
          if (isLoading) {
            content = const SkeletonList(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 16),
              thumbSize: 40,
              circleThumb: true,
            );
          } else if (isEmpty || rest.isEmpty) {
            content = _EmptyMessage(
              icon: isEmpty ? AppIcons.trophy : AppIcons.usersGroup,
              title: isEmpty
                  ? 'Sii il primo a segnalare!'
                  : entries.length < 3
                  ? 'C\'è ancora posto sul podio!'
                  : 'Il podio è al completo!',
              message: isEmpty
                  ? 'La classifica si aggiorna a ogni segnalazione.'
                  : entries.length < 3
                  ? 'Segnala o pulisci una zona per entrare in classifica.'
                  : 'Non ci sono ancora altri utenti in classifica.',
              bottomPadding: showMe ? 100 : 24,
            );
          } else {
            content = ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, 14, 16, showMe ? 104 : 24),
              itemCount: rest.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final r = rest[i];
                return _RankRow(
                  entry: r,
                  reportCount: _viewModel.reportCountFor(r.uid),
                  isCurrentUser: r.uid == currentUid,
                );
              },
            );
          }

          return Column(
            children: [
              _HeroHeader(
                loading: _viewModel.loading && top.isEmpty,
                top: top,
                viewModel: _viewModel,
              ),
              Expanded(
                child: ColoredBox(
                  color: AppColors.greenLight,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: RefreshIndicator(
                          onRefresh: _reload,
                          child: content,
                        ),
                      ),
                      if (showMe)
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12,
                          child: _MyRow(
                            uid: currentUid,
                            name: myName,
                            points: me.points,
                            rank: me.rank,
                            hint: _climbHint(entries, me.points, me.rank),
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

  /// Quanto manca per salire: "1 segnalazione e superi Giulia".
  static String _climbHint(
    List<LeaderboardEntry> entries,
    int myPoints,
    int myRank,
  ) {
    if (myRank == 1 && myPoints > 0) return 'Sei in testa, continua così!';
    final above = entries.where((e) => e.points > myPoints).toList();
    if (above.isEmpty) {
      return myPoints == 0
          ? 'Fai la prima segnalazione per entrare in classifica'
          : 'Continua così!';
    }
    final next = above.last;
    final missing = next.points - myPoints + 1;
    final effort = missing == 1
        ? '1 segnalazione'
        : missing == pointsPerCleanup
        ? '1 pulizia'
        : '$missing punti';
    return '$effort e superi ${next.name}';
  }
}

/// Testata verde foresta: titolo, sottotitolo e podio dei primi tre.
class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.loading,
    required this.top,
    required this.viewModel,
  });

  final bool loading;
  final List<LeaderboardEntry> top;
  final ClassificaViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppColors.forest,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: topInset + 40,
            child: Icon(
              AppIcons.leaf,
              size: 220,
              color: Colors.white.withAlpha(20),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, topInset + 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TabHeader(
                  title: 'Classifica',
                  onDark: true,
                  actions: [NotificationsBell(onDark: true)],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Chi ha fatto di più per il territorio',
                  style: TextStyle(fontSize: 14, color: AppColors.mintText),
                ),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  )
                else if (top.isEmpty)
                  const SizedBox(height: 24)
                else ...[
                  const SizedBox(height: 28),
                  _Podium(entries: top, viewModel: viewModel),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.entries, required this.viewModel});

  final List<LeaderboardEntry> entries;
  final ClassificaViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    LeaderboardEntry? at(int i) => i < entries.length ? entries[i] : null;
    Widget slot(LeaderboardEntry? e, double barHeight) => Expanded(
      child: e == null
          ? const SizedBox.shrink()
          : _PodiumSlot(
              entry: e,
              barHeight: barHeight,
              reportCount: viewModel.reportCountFor(e.uid),
            ),
    );
    // Secondo a sinistra, primo al centro (più alto), terzo a destra.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        slot(at(1), 96),
        const SizedBox(width: 10),
        slot(at(0), 136),
        const SizedBox(width: 10),
        slot(at(2), 76),
      ],
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  const _PodiumSlot({
    required this.entry,
    required this.barHeight,
    required this.reportCount,
  });

  final LeaderboardEntry entry;
  final double barHeight;
  final int? reportCount;

  @override
  Widget build(BuildContext context) {
    final first = entry.rank == 1;
    final fg = first ? AppColors.onYellow : Colors.white;
    return Semantics(
      label:
          '${entry.rank}° posto, ${entry.name}, ${entry.points} punti'
          '${reportCount == null ? '' : ', ${_reportsLabel(reportCount!)}'}',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Padding(
                padding: EdgeInsets.only(top: first ? 22 : 0),
                child: UserAvatar(
                  name: entry.name,
                  seed: entry.uid,
                  size: first ? 76 : 60,
                  tint: first
                      ? (bg: const Color(0xFFFFE3A3), fg: AppColors.yellowText)
                      : null,
                  ring: first
                      ? (color: AppColors.yellow, width: 4)
                      : (color: Colors.white.withAlpha(64), width: 4),
                ),
              ),
              if (first)
                const Icon(AppIcons.crown, size: 24, color: AppColors.yellow),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              height: 20 / 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Text(
            reportCount == null ? '' : _reportsLabel(reportCount!),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              height: 16 / 12,
              color: AppColors.mintText,
            ),
          ),
          const SizedBox(height: 8),
          // Altezza minima, non fissa: con il testo ingrandito
          // (accessibilità) la colonna cresce invece di tagliare i numeri.
          Container(
            constraints: BoxConstraints(minHeight: barHeight),
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: first ? AppColors.yellow : Colors.white.withAlpha(31),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            child: IntrinsicHeight(
              child: Stack(
                // Il Column non occupa tutta la larghezza: va centrato.
                alignment: Alignment.topCenter,
                children: [
                  if (first)
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 6,
                      child: ColoredBox(color: AppColors.yellowEdge),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 14),
                    child: Column(
                      children: [
                        Text(
                          '${entry.points}',
                          style: TextStyle(
                            fontSize: first ? 30 : 24,
                            height: 32 / 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                            color: fg,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          'punti',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: fg.withAlpha(204),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Spacer(),
                        Text(
                          '${entry.rank}°',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: fg.withAlpha(140),
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
      ),
    );
  }
}

String _reportsLabel(int n) => n == 1 ? '1 segnalazione' : '$n segnalazioni';

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
    return Semantics(
      label:
          '${entry.rank}° posto, ${isCurrentUser ? 'tu' : entry.name}, '
          '${entry.points} punti',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: isCurrentUser
              ? Border.all(color: AppColors.yellow, width: 2)
              : null,
          boxShadow: const [
            BoxShadow(color: AppColors.mintBorder, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '${entry.rank}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDisabled,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 12),
            UserAvatar(name: entry.name, seed: entry.uid),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCurrentUser ? 'Tu, ${entry.name}' : entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 20 / 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (reportCount != null)
                    Text(
                      _reportsLabel(reportCount!),
                      style: const TextStyle(
                        fontSize: 12,
                        height: 16 / 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            _Points(points: entry.points, color: AppColors.greenBrand),
          ],
        ),
      ),
    );
  }
}

class _Points extends StatelessWidget {
  const _Points({required this.points, required this.color, this.unitColor});

  final int points;
  final Color color;
  final Color? unitColor;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$points',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          TextSpan(
            text: ' pt',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: unitColor ?? AppColors.textDisabled,
            ),
          ),
        ],
      ),
    );
  }
}

/// La tua riga, gialla e sempre visibile in fondo, con quanto manca per
/// salire.
class _MyRow extends StatelessWidget {
  const _MyRow({
    required this.uid,
    required this.name,
    required this.points,
    required this.rank,
    required this.hint,
  });

  final String uid;
  final String name;
  final int points;
  final int rank;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'La tua posizione: $rank°, $points punti. $hint',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        decoration: BoxDecoration(
          color: AppColors.yellow,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            const BoxShadow(color: AppColors.yellowEdge, offset: Offset(0, 4)),
            BoxShadow(
              color: AppColors.textPrimary.withAlpha(51),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '$rank',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.onYellow,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 12),
            UserAvatar(
              name: name,
              seed: uid,
              ring: (color: Colors.white, width: 4),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tu, $name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 20 / 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onYellow,
                    ),
                  ),
                  Text(
                    hint,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 16 / 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onYellow.withAlpha(204),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _Points(
              points: points,
              color: AppColors.onYellow,
              unitColor: AppColors.onYellow.withAlpha(179),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.bottomPadding,
  });

  final IconData icon;
  final String title;
  final String message;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: EdgeInsets.fromLTRB(32, 24, 32, bottomPadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 34, color: AppColors.greenBrand),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
