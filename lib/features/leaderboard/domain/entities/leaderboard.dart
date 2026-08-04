import 'package:equatable/equatable.dart';

import '../../../../core/network/api_response.dart';

/// `GET /student/practice/leaderboard` → rows plus the caller's own standing.
class LeaderboardPage extends Equatable {
  const LeaderboardPage({
    required this.rows,
    required this.pagination,
    required this.scope,
    required this.period,
    this.me,
  });

  final List<LeaderboardRow> rows;
  final Pagination pagination;

  /// The caller's own rank — null until they've solved something.
  final LeaderboardMe? me;
  final String scope;
  final String period;

  @override
  List<Object?> get props => [rows, pagination, me, scope, period];
}

class LeaderboardRow extends Equatable {
  const LeaderboardRow({
    required this.rank,
    required this.points,
    required this.solved,
    this.studentId,
    this.userId,
    this.username,
    this.fullName,
    this.avatar,
    this.rollNumber,
    this.accuracy,
    this.badgeCount = 0,
    this.isMe = false,
  });

  final int rank;
  final int points;
  final int solved;
  final String? studentId;
  final String? userId;
  final String? username;
  final String? fullName;
  final String? avatar;
  final String? rollNumber;

  /// 0–100, or null when the student has never attempted anything.
  final int? accuracy;
  final int badgeCount;
  final bool isMe;

  String get displayName => (fullName ?? '').isNotEmpty ? fullName! : '—';

  @override
  List<Object?> get props => [rank, points, solved, studentId, username, isMe];
}

/// The caller's own standing, shown in the "Your rank" banner.
class LeaderboardMe extends Equatable {
  const LeaderboardMe({
    required this.rank,
    required this.points,
    required this.solved,
    this.accuracy,
  });

  final int rank;
  final int points;
  final int solved;
  final int? accuracy;

  @override
  List<Object?> get props => [rank, points, solved, accuracy];
}

/// Scope and period options, matching the backend validator.
class LeaderboardScope {
  const LeaderboardScope._();

  static const school = 'school';
  static const batch = 'batch';
  static const department = 'department';

  /// The API also accepts `semester`, but the React UI never exposes it, so
  /// neither does this client.
  static const options = [school, batch, department];

  static String label(String scope) => switch (scope) {
        school => 'School',
        batch => 'Batch',
        department => 'Department',
        _ => scope,
      };
}

class LeaderboardPeriod {
  const LeaderboardPeriod._();

  static const today = 'today';
  static const weekly = 'weekly';
  static const monthly = 'monthly';
  static const yearly = 'yearly';
  static const allTime = 'all_time';

  static const options = [today, weekly, monthly, yearly, allTime];

  /// The React default.
  static const defaultPeriod = allTime;

  static String label(String period) => switch (period) {
        today => 'Today',
        weekly => 'This week',
        monthly => 'This month',
        yearly => 'This year',
        allTime => 'All time',
        _ => period,
      };
}
