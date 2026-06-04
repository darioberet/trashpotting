import 'package:flutter/material.dart';

import '../models/leaderboard_entry.dart';
import '../repositories/leaderboard_repository.dart';
import '../state/app_session.dart';

/// Classifica community (dati mock fino a query Firestore).
class ClassificaScreen extends StatefulWidget {
  ClassificaScreen({super.key, LeaderboardRepository? repository})
      : _repository = repository ?? FirestoreLeaderboardRepository();

  final LeaderboardRepository _repository;

  @override
  State<ClassificaScreen> createState() => _ClassificaScreenState();
}

class _ClassificaScreenState extends State<ClassificaScreen> {
  late Future<List<LeaderboardEntry>> _future;
  Object? _lastPublishedError;

  static const _mock = <LeaderboardEntry>[
    LeaderboardEntry(rank: 1, name: 'Tu (placeholder)', points: 120),
    LeaderboardEntry(rank: 2, name: 'EcoTeam Nord', points: 98),
    LeaderboardEntry(rank: 3, name: 'Raccolta_2026', points: 76),
    LeaderboardEntry(rank: 4, name: 'VerdeStrada', points: 54),
    LeaderboardEntry(rank: 5, name: 'PuliamoIlParco', points: 41),
  ];

  @override
  void initState() {
    super.initState();
    _future = widget._repository.fetchTop();
  }

  Future<void> _reload() async {
    setState(() {
      _future = widget._repository.fetchTop();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final session = AppSessionScope.of(context);

    return FutureBuilder<List<LeaderboardEntry>>(
      future: _future,
      builder: (context, snapshot) {
        final entries = (snapshot.data?.isNotEmpty ?? false) ? snapshot.data! : _mock;
        if (snapshot.hasError && snapshot.error != _lastPublishedError) {
          _lastPublishedError = snapshot.error;
          session.publishError(
            snapshot.error!,
            fallback: 'Classifica non disponibile: mostro dati di esempio.',
          );
        }

        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: entries.length + 1,
            separatorBuilder: (_, i) => i == 0 ? const SizedBox.shrink() : const Divider(height: 1),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12, top: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Classifica',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.primary,
                          ),
                        ),
                    ],
                  ),
                );
              }
              final r = entries[i - 1];
              final medal = r.rank == 1
                  ? '🥇'
                  : r.rank == 2
                      ? '🥈'
                      : r.rank == 3
                          ? '🥉'
                          : '${r.rank}.';
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                leading: CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  foregroundColor: cs.onPrimaryContainer,
                  child: Text(
                    medal.length > 2 ? '${r.rank}' : medal,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                title: Text(r.name),
                trailing: Text(
                  '${r.points} pt',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
