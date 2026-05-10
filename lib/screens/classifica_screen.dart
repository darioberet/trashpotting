import 'package:flutter/material.dart';

class _Row {
  const _Row(this.rank, this.name, this.points);
  final int rank;
  final String name;
  final int points;
}

/// Classifica community (dati mock fino a query Firestore).
class ClassificaScreen extends StatelessWidget {
  const ClassificaScreen({super.key});

  static const _mock = <_Row>[
    _Row(1, 'Tu (placeholder)', 120),
    _Row(2, 'EcoTeam Nord', 98),
    _Row(3, 'Raccolta_2026', 76),
    _Row(4, 'VerdeStrada', 54),
    _Row(5, 'PuliamoIlParco', 41),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _mock.length + 1,
      separatorBuilder: (_, i) => i == 0 ? const SizedBox.shrink() : const Divider(height: 1),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 4),
            child: Text(
              'Classifica',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }
        final r = _mock[i - 1];
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
    );
  }
}
