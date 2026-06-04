import 'package:flutter/material.dart';

import '../models/leaderboard_entry.dart';
import '../repositories/leaderboard_repository.dart';
import '../state/app_session.dart';
import '../state/classifica_view_model.dart';

/// Classifica community (dati mock fino a query Firestore).
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
    final session = AppSessionScope.of(context);

    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        if (_viewModel.errorToken > _seenErrorToken && _viewModel.lastError != null) {
          _seenErrorToken = _viewModel.errorToken;
          session.publishError(
            _viewModel.lastError!,
            fallback: _viewModel.lastErrorFallback,
          );
        }

        final entries = _viewModel.entries;
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
                      if (_viewModel.loading)
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
              final LeaderboardEntry r = entries[i - 1];
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
