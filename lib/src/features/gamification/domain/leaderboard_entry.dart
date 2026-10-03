class LeaderboardEntry {
  final String userId;
  final String displayName;
  final String? photoUrl;
  final String district;
  final int totalPoints;
  final int rank;

  const LeaderboardEntry({
    required this.userId,
    required this.displayName,
    this.photoUrl,
    required this.district,
    required this.totalPoints,
    required this.rank,
  });
}
