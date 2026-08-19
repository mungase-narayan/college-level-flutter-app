import 'package:equatable/equatable.dart';
import 'package:flutter/painting.dart';

import '../../../../core/network/api_response.dart';

/// `GET /student/contest-ratings/me`.
class ContestRating extends Equatable {
  const ContestRating({
    required this.rating,
    required this.peakRating,
    required this.contestsPlayed,
    required this.tier,
    required this.tierColor,
    required this.isProvisional,
    this.history = const [],
  });

  final int rating;
  final int peakRating;
  final int contestsPlayed;

  /// Tier name resolved server-side, e.g. `Specialist`.
  final String tier;

  /// Hex string from the backend's `RATING_TIERS`, e.g. `#03a89e`.
  final String tierColor;

  /// True when the student has never been in a rated contest — the value shown
  /// is the starting rating everyone begins with, not an earned one.
  final bool isProvisional;

  /// Every rated contest, oldest first, for the rating curve.
  final List<RatingHistoryEntry> history;

  /// [tierColor] parsed for Flutter; falls back to grey on a malformed value.
  Color get color => RatingTier.parseHex(tierColor) ?? const Color(0xFF808080);

  /// The best positive rating gain, for the "Best gain +N" footer.
  int? get bestGain {
    final gains = history
        .map((entry) => entry.ratingDelta)
        .whereType<int>()
        .where((delta) => delta > 0);
    if (gains.isEmpty) return null;
    return gains.reduce((a, b) => a > b ? a : b);
  }

  @override
  List<Object?> get props =>
      [rating, peakRating, contestsPlayed, tier, tierColor, isProvisional, history];
}

/// One rated contest in the student's history.
class RatingHistoryEntry extends Equatable {
  const RatingHistoryEntry({
    required this.contestId,
    required this.contestTitle,
    this.endAt,
    this.rank,
    this.participants,
    this.ratingBefore,
    this.ratingAfter,
    this.ratingDelta,
  });

  final String contestId;
  final String contestTitle;
  final String? endAt;
  final int? rank;
  final int? participants;
  final int? ratingBefore;
  final int? ratingAfter;
  final int? ratingDelta;

  @override
  List<Object?> get props => [
        contestId,
        contestTitle,
        endAt,
        rank,
        participants,
        ratingBefore,
        ratingAfter,
        ratingDelta,
      ];
}

/// The rating ladder, identical in the backend's `contest.constants.ts` and the
/// web's `admin/contests/constants.ts`. `from` is inclusive; highest first.
/// `GET /student/contest-ratings/leaderboard` — the school's rated students.
class RatingLeaderboard extends Equatable {
  const RatingLeaderboard({
    required this.entries,
    required this.pagination,
    this.myRank,
  });

  final List<RatingLeaderboardEntry> entries;
  final Pagination pagination;

  /// The caller's own position, computed across the whole school rather than
  /// the visible page — so it stays right even when they are not on it.
  ///
  /// Null until they have been in a rated contest. Not zero: `#0` is not a rank.
  final int? myRank;

  @override
  List<Object?> get props => [entries, pagination, myRank];
}

class RatingLeaderboardEntry extends Equatable {
  const RatingLeaderboardEntry({
    required this.studentId,
    required this.rank,
    required this.rating,
    required this.peakRating,
    required this.contestsPlayed,
    required this.name,
    required this.username,
    required this.tier,
    required this.tierColor,
    this.avatarUrl,
    this.rollNumber,
    this.isCurrentUser = false,
  });

  final String studentId;
  final int rank;
  final int rating;
  final int peakRating;
  final int contestsPlayed;
  final String name;
  final String username;
  final String tier;
  final String tierColor;
  final String? avatarUrl;
  final String? rollNumber;
  final bool isCurrentUser;

  /// [tierColor] parsed for Flutter; falls back to grey on a malformed value.
  Color get color => RatingTier.parseHex(tierColor) ?? const Color(0xFF808080);

  @override
  List<Object?> get props => [studentId, rank, rating, username, isCurrentUser];
}

class RatingTier {
  const RatingTier(this.name, this.from, this.hex);

  final String name;
  final int from;
  final String hex;

  Color get color => parseHex(hex) ?? const Color(0xFF808080);

  static const all = <RatingTier>[
    RatingTier('Grandmaster', 2400, '#ff0000'),
    RatingTier('International Master', 2300, '#ff8c00'),
    RatingTier('Master', 2100, '#ff8c00'),
    RatingTier('Candidate Master', 1900, '#aa00aa'),
    RatingTier('Expert', 1600, '#0000ff'),
    RatingTier('Specialist', 1400, '#03a89e'),
    RatingTier('Pupil', 1200, '#008000'),
    RatingTier('Newbie', 0, '#808080'),
  ];

  /// Everyone starts here.
  static const defaultRating = 1200;

  static RatingTier resolve(int rating) =>
      all.firstWhere((tier) => rating >= tier.from, orElse: () => all.last);

  /// Parses `#rrggbb`; null when absent or malformed.
  ///
  /// Deliberately not delegating to `parseHexColor` in the theme module: this
  /// is a domain entity, and the presentation layer's colour helpers are not
  /// something the domain should have to import.
  static Color? parseHex(String? hex) {
    if (hex == null) return null;
    final cleaned = hex.replaceFirst('#', '').trim();
    if (cleaned.length != 6) return null;
    final value = int.tryParse(cleaned, radix: 16);
    return value == null ? null : Color(0xFF000000 | value);
  }
}
