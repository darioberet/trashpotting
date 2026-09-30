class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.uid,
    required this.name,
    required this.points,
  });

  final int rank;
  final String uid;
  final String name;
  final int points;
}
