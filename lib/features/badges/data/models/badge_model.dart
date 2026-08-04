import '../../domain/entities/badge.dart';

int _int(Object? value, [int fallback = 0]) => (value as num?)?.toInt() ?? fallback;
List<Map<String, dynamic>> _maps(Object? value) =>
    (value as List?)?.whereType<Map<String, dynamic>>().toList(growable: false) ??
    const [];

/// JSON → [BadgeCollection].
class BadgeCollectionModel extends BadgeCollection {
  const BadgeCollectionModel({super.earned, super.catalog});

  factory BadgeCollectionModel.fromJson(Map<String, dynamic> json) =>
      BadgeCollectionModel(
        earned: _maps(json['earned'])
            .map(EarnedBadgeModel.fromJson)
            .toList(growable: false),
        catalog: _maps(json['catalog'])
            .map(BadgeDefinitionModel.fromJson)
            .toList(growable: false),
      );
}

class EarnedBadgeModel extends EarnedBadge {
  const EarnedBadgeModel({
    required super.badgeKey,
    required super.name,
    required super.category,
    required super.tier,
    super.period,
    super.earnedAt,
    super.threshold,
  });

  factory EarnedBadgeModel.fromJson(Map<String, dynamic> json) => EarnedBadgeModel(
        badgeKey: json['badgeKey'] as String? ?? '',
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? '',
        // Daily-challenge rows may omit the tier; the web defaults them to gold.
        tier: json['tier'] as String? ?? 'gold',
        period: json['period'] as String?,
        earnedAt: json['earnedAt'] as String?,
        threshold: _int(json['threshold']),
      );
}

class BadgeDefinitionModel extends BadgeDefinition {
  const BadgeDefinitionModel({
    required super.key,
    required super.name,
    required super.description,
    required super.category,
    required super.tier,
    super.threshold,
  });

  factory BadgeDefinitionModel.fromJson(Map<String, dynamic> json) =>
      BadgeDefinitionModel(
        key: json['key'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        category: json['category'] as String? ?? '',
        tier: json['tier'] as String? ?? 'bronze',
        threshold: _int(json['threshold']),
      );
}
