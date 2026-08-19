import 'package:equatable/equatable.dart';

import '../../../../core/common/widgets/heatmap_grid.dart';

/// `GET /public/students/:username` — a student's public showcase.
///
/// The endpoint is unauthenticated: this is the page anyone reaches by tapping a
/// name on the leaderboard, so it carries only what a student has chosen to make
/// public. Nothing here is scoped to the caller.
class PublicProfile extends Equatable {
  const PublicProfile({
    required this.username,
    required this.stats,
    required this.heatmapDays,
    required this.badges,
    required this.recentSolved,
    this.fullName,
    this.avatar,
    this.schoolName,
    this.heatmapToday,
  });

  final String username;
  final String? fullName;
  final String? avatar;
  final String? schoolName;
  final PublicProfileStats stats;

  /// Reuses the core heatmap's own day type so `HeatmapGrid` takes it directly.
  final List<HeatmapDay> heatmapDays;
  /// Anchors the grid's last column. A [DateTime] so `HeatmapGrid` takes it
  /// directly rather than every caller re-parsing the wire string.
  final DateTime? heatmapToday;
  final List<PublicBadge> badges;
  final List<RecentSolved> recentSolved;

  String get displayName =>
      (fullName ?? '').isNotEmpty ? fullName! : username;

  /// Default usernames are full email addresses, so `@dev.shah@x.edu` would read
  /// as a double-`@`. The web trims to the part before the domain; so does this.
  String get handle {
    final cut = username.split('@').first;
    return cut.isNotEmpty ? cut : username;
  }

  @override
  List<Object?> get props =>
      [username, fullName, avatar, schoolName, stats, badges, recentSolved];
}

class PublicProfileStats extends Equatable {
  const PublicProfileStats({
    this.solved = 0,
    this.currentStreak = 0,
    this.points = 0,
    this.rank,
    this.totalStudents = 0,
  });

  final int solved;
  final int currentStreak;
  final int points;

  /// Null when the student has never placed — shown as "Unranked", not "#0".
  final int? rank;
  final int totalStudents;

  @override
  List<Object?> get props => [solved, currentStreak, points, rank, totalStudents];
}

class PublicBadge extends Equatable {
  const PublicBadge({
    required this.badgeKey,
    required this.name,
    required this.tier,
    required this.category,
    required this.period,
    this.earnedAt,
  });

  final String badgeKey;
  final String name;
  final String tier;
  final String category;

  /// Distinguishes repeat awards of the same badge, so it belongs in the key.
  final String period;
  final DateTime? earnedAt;

  @override
  List<Object?> get props => [badgeKey, name, tier, category, period, earnedAt];
}

class RecentSolved extends Equatable {
  const RecentSolved({
    required this.questionId,
    required this.title,
    required this.difficulty,
    this.solvedAt,
  });

  final String questionId;
  final String title;
  final String difficulty;
  final DateTime? solvedAt;

  @override
  List<Object?> get props => [questionId, title, difficulty, solvedAt];
}
