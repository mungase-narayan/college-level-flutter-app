import '../../../../../core/network/api_response.dart';
import '../../domain/entities/leaderboard.dart';

int _int(Object? value, [int fallback = 0]) => (value as num?)?.toInt() ?? fallback;
int? _intOrNull(Object? value) => (value as num?)?.toInt();

/// JSON → [LeaderboardStandings].
class LeaderboardStandingsModel extends LeaderboardStandings {
  const LeaderboardStandingsModel({
    required super.rows,
    required super.pagination,
    required super.scope,
    required super.period,
    super.me,
  });

  factory LeaderboardStandingsModel.fromJson(Map<String, dynamic> json) =>
      LeaderboardStandingsModel(
        rows: ((json['data'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(LeaderboardRowModel.fromJson)
            .toList(growable: false),
        pagination: Pagination.fromJson(json['pagination'] as Map<String, dynamic>?),
        me: json['me'] is Map<String, dynamic>
            ? _me(json['me'] as Map<String, dynamic>)
            : null,
        scope: json['scope'] as String? ?? LeaderboardScope.school,
        period: json['period'] as String? ?? LeaderboardPeriod.defaultPeriod,
      );

  static LeaderboardMe _me(Map<String, dynamic> json) => LeaderboardMe(
        rank: _int(json['rank']),
        points: _int(json['points']),
        solved: _int(json['solved']),
        accuracy: _intOrNull(json['accuracy']),
      );
}

class LeaderboardRowModel extends LeaderboardRow {
  const LeaderboardRowModel({
    required super.rank,
    required super.points,
    required super.solved,
    super.studentId,
    super.userId,
    super.username,
    super.fullName,
    super.avatar,
    super.rollNumber,
    super.accuracy,
    super.badgeCount,
    super.isMe,
  });

  factory LeaderboardRowModel.fromJson(Map<String, dynamic> json) =>
      LeaderboardRowModel(
        rank: _int(json['rank']),
        points: _int(json['points']),
        solved: _int(json['solved']),
        studentId: json['studentId'] as String?,
        userId: json['userId'] as String?,
        username: json['username'] as String?,
        fullName: json['fullName'] as String?,
        avatar: json['avatar'] as String?,
        rollNumber: json['rollNumber'] as String?,
        accuracy: _intOrNull(json['accuracy']),
        badgeCount: _int(json['badgeCount']),
        // The server calls this `isCurrentUser`; the entity calls it `isMe`
        // because that reads better at the call site. Do not "correct" the key
        // to match the field — reading `isMe` here silently disables the
        // current-user row highlight, which is how it was broken before.
        isMe: json['isCurrentUser'] as bool? ?? false,
      );
}
