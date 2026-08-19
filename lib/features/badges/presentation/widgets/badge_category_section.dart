import 'package:flutter/material.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../domain/entities/badge.dart';
import 'badge_card.dart';

/// One category of the badge wall — a header with an earned count, then the
/// cards.
///
/// Cards stack in a single column rather than the web's `sm:grid-cols-2
/// lg:grid-cols-3`. That is what the web itself renders at phone width, and it
/// matches the house treatment of responsive grids elsewhere (the dashboard
/// collapses `sm:grid-cols-3` to one column for the same reason).
class BadgeCategorySection extends StatelessWidget {
  const BadgeCategorySection({
    super.key,
    required this.category,
    required this.definitions,
    required this.badges,
  });

  final String category;

  /// The catalog entries for this category, in catalog order.
  final List<BadgeDefinition> definitions;

  final BadgeCollection badges;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    // Hoisted: the getter rebuilds the map on every access, and indexing it
    // per card would make the section quadratic.
    final earnedByKey = badges.earnedByKey;
    final isDaily = category == BadgeCategory.dailyChallenge;
    final daily = isDaily ? badges.dailyEarned : const <EarnedBadge>[];

    final cards = <Widget>[
      if (!isDaily)
        for (final definition in definitions)
          BadgeCard(definition: definition, earned: earnedByKey[definition.key])
      // The daily-challenge badge recurs monthly, so each completed month gets
      // its own card. The catalog holds one locked template standing in for all
      // of them, shown only while nothing has been earned.
      else if (daily.isNotEmpty)
        for (final badge in daily)
          BadgeCard(
            definition: BadgeDefinition.fromDailyEarned(badge),
            earned: badge,
          )
      else if (definitions.isNotEmpty)
        BadgeCard(definition: definitions.first),
    ];

    final pill = isDaily
        ? '${daily.length} earned'
        : '${definitions.where((d) => earnedByKey.containsKey(d.key)).length}'
            '/${definitions.length}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Icon(
                BadgeCategory.icon(category),
                size: 16,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                BadgeCategory.label(category),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
            ),
            const SizedBox(width: 8),
            AppBadge(pill, shade: TwColors.slate, dense: true),
          ],
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < cards.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == cards.length - 1 ? 0 : 10),
            child: cards[i],
          ),
      ],
    );
  }
}
