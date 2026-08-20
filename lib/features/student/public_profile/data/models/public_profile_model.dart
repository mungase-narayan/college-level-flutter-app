import '../../../../../core/common/widgets/heatmap_grid.dart';
import '../../domain/entities/public_profile.dart';

int _int(Object? value, [int fallback = 0]) => (value as num?)?.toInt() ?? fallback;
int? _intOrNull(Object? value) => (value as num?)?.toInt();
DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

/// JSON → [PublicProfile].
class PublicProfileModel extends PublicProfile {
  const PublicProfileModel({
    required super.username,
    required super.stats,
    required super.heatmapDays,
    required super.badges,
    required super.recentSolved,
    super.fullName,
    super.avatar,
    super.schoolName,
    super.heatmapToday,
  });

  factory PublicProfileModel.fromJson(Map<String, dynamic> json) {
    final heatmap = json['heatmap'] as Map<String, dynamic>?;

    return PublicProfileModel(
      username: json['username'] as String? ?? '',
      fullName: json['fullName'] as String?,
      avatar: json['avatar'] as String?,
      schoolName: json['schoolName'] as String?,
      stats: _stats(json['stats'] as Map<String, dynamic>?),
      heatmapToday: _date(heatmap?['today']),
      heatmapDays: ((heatmap?['days'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(HeatmapDay.fromJson)
          .toList(growable: false),
      badges: ((json['badges'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_badge)
          .toList(growable: false),
      recentSolved: ((json['recentSolved'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_solved)
          .toList(growable: false),
    );
  }

  static PublicProfileStats _stats(Map<String, dynamic>? json) =>
      PublicProfileStats(
        solved: _int(json?['solved']),
        currentStreak: _int(json?['currentStreak']),
        points: _int(json?['points']),
        // Deliberately nullable: an unranked student is not rank 0.
        rank: _intOrNull(json?['rank']),
        totalStudents: _int(json?['totalStudents']),
      );

  static PublicBadge _badge(Map<String, dynamic> json) => PublicBadge(
        badgeKey: json['badgeKey'] as String? ?? '',
        name: json['name'] as String? ?? '',
        tier: json['tier'] as String? ?? '',
        category: json['category'] as String? ?? '',
        period: json['period'] as String? ?? '',
        earnedAt: _date(json['earnedAt']),
      );

  static RecentSolved _solved(Map<String, dynamic> json) => RecentSolved(
        questionId: json['questionId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        difficulty: json['difficulty'] as String? ?? '',
        solvedAt: _date(json['solvedAt']),
      );
}
