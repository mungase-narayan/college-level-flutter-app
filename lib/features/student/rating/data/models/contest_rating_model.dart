import '../../../../../core/network/api_response.dart';
import '../../domain/entities/contest_rating.dart';

int _int(Object? value, [int fallback = 0]) => (value as num?)?.toInt() ?? fallback;
int? _intOrNull(Object? value) => (value as num?)?.toInt();

/// JSON → [ContestRating].
class ContestRatingModel extends ContestRating {
  const ContestRatingModel({
    required super.rating,
    required super.peakRating,
    required super.contestsPlayed,
    required super.tier,
    required super.tierColor,
    required super.isProvisional,
    super.history,
  });

  factory ContestRatingModel.fromJson(Map<String, dynamic> json) {
    final rating = _int(json['rating'], RatingTier.defaultRating);
    return ContestRatingModel(
      rating: rating,
      peakRating: _int(json['peakRating'], RatingTier.defaultRating),
      contestsPlayed: _int(json['contestsPlayed']),
      // The server resolves the tier; fall back to the local ladder so the UI
      // still colours correctly if the fields are ever omitted.
      tier: json['tier'] as String? ?? RatingTier.resolve(rating).name,
      tierColor: json['tierColor'] as String? ?? RatingTier.resolve(rating).hex,
      isProvisional: json['isProvisional'] as bool? ?? false,
      history: ((json['history'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(RatingHistoryEntryModel.fromJson)
          .toList(growable: false),
    );
  }
}

/// JSON → [RatingLeaderboard].
class RatingLeaderboardModel extends RatingLeaderboard {
  const RatingLeaderboardModel({
    required super.entries,
    required super.pagination,
    super.myRank,
  });

  factory RatingLeaderboardModel.fromJson(Map<String, dynamic> json) =>
      RatingLeaderboardModel(
        entries: ((json['entries'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(RatingLeaderboardEntryModel.fromJson)
            .toList(growable: false),
        pagination: Pagination.fromJson(json['pagination'] as Map<String, dynamic>?),
        // `_intOrNull`, never `_int`: a student who has never been rated has no
        // rank at all, and defaulting to 0 would render as "#0".
        myRank: _intOrNull(json['myRank']),
      );
}

class RatingLeaderboardEntryModel extends RatingLeaderboardEntry {
  const RatingLeaderboardEntryModel({
    required super.studentId,
    required super.rank,
    required super.rating,
    required super.peakRating,
    required super.contestsPlayed,
    required super.name,
    required super.username,
    required super.tier,
    required super.tierColor,
    super.avatarUrl,
    super.rollNumber,
    super.isCurrentUser,
  });

  factory RatingLeaderboardEntryModel.fromJson(Map<String, dynamic> json) {
    final rating = _int(json['rating'], RatingTier.defaultRating);
    return RatingLeaderboardEntryModel(
      studentId: json['studentId'] as String? ?? '',
      rank: _int(json['rank']),
      rating: rating,
      peakRating: _int(json['peakRating'], RatingTier.defaultRating),
      contestsPlayed: _int(json['contestsPlayed']),
      name: json['name'] as String? ?? '',
      username: json['username'] as String? ?? '',
      tier: json['tier'] as String? ?? RatingTier.resolve(rating).name,
      tierColor: json['tierColor'] as String? ?? RatingTier.resolve(rating).hex,
      avatarUrl: json['avatarUrl'] as String?,
      rollNumber: json['rollNumber'] as String?,
      // This endpoint really does send `isCurrentUser` — unlike the practice
      // leaderboard, whose entity calls the same idea `isMe`.
      isCurrentUser: json['isCurrentUser'] as bool? ?? false,
    );
  }
}

class RatingHistoryEntryModel extends RatingHistoryEntry {
  const RatingHistoryEntryModel({
    required super.contestId,
    required super.contestTitle,
    super.endAt,
    super.rank,
    super.participants,
    super.ratingBefore,
    super.ratingAfter,
    super.ratingDelta,
  });

  factory RatingHistoryEntryModel.fromJson(Map<String, dynamic> json) =>
      RatingHistoryEntryModel(
        contestId: json['contestId'] as String? ?? '',
        contestTitle: json['contestTitle'] as String? ?? '',
        endAt: json['endAt'] as String?,
        rank: _intOrNull(json['rank']),
        participants: _intOrNull(json['participants']),
        ratingBefore: _intOrNull(json['ratingBefore']),
        ratingAfter: _intOrNull(json['ratingAfter']),
        ratingDelta: _intOrNull(json['ratingDelta']),
      );
}
