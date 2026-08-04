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
