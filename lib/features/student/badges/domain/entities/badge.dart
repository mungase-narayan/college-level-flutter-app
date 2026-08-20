import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../../../../core/config/theme/app_colors.dart';

/// `GET /student/practice/badges` → `{ earned, catalog }`.
///
/// Badge *definitions* live in backend code, not the database — only earned
/// rows persist — so the catalog is what tells the UI which badges exist to be
/// locked.
class BadgeCollection extends Equatable {
  const BadgeCollection({this.earned = const [], this.catalog = const []});

  final List<EarnedBadge> earned;
  final List<BadgeDefinition> catalog;

  /// The newest earned record per `badgeKey`. Monthly and yearly badges can
  /// recur per period, so the latest wins.
  Map<String, EarnedBadge> get earnedByKey {
    final byKey = <String, EarnedBadge>{};
    for (final badge in earned) {
      final existing = byKey[badge.badgeKey];
      if (existing == null ||
          (badge.earnedAt ?? '').compareTo(existing.earnedAt ?? '') > 0) {
        byKey[badge.badgeKey] = badge;
      }
    }
    return byKey;
  }

  /// Daily-challenge badges, newest month first.
  ///
  /// Each completed month is its **own** card — never collapsed into one — so
  /// a student sees "July 2026", "June 2026", and so on.
  List<EarnedBadge> get dailyEarned {
    final daily = earned
        .where((badge) => badge.category == BadgeCategory.dailyChallenge)
        .toList()
      ..sort((a, b) => (b.period ?? '').compareTo(a.period ?? ''));
    return daily;
  }

  /// Distinct non-daily badges earned, plus one per completed daily month.
  int get earnedCount {
    final nonDaily = earnedByKey.keys
        .where((key) => key != BadgeCategory.dailyPerfectMonthKey)
        .length;
    return nonDaily + dailyEarned.length;
  }

  /// Catalog size with the single daily template swapped for the actual months.
  int get totalCount {
    final nonDaily = catalog
        .where((def) => def.category != BadgeCategory.dailyChallenge)
        .length;
    return nonDaily + dailyEarned.length;
  }

  int get progressPercent =>
      totalCount == 0 ? 0 : ((earnedCount / totalCount) * 100).round();

  /// Catalog grouped by category, preserving catalog order.
  Map<String, List<BadgeDefinition>> get grouped {
    final groups = <String, List<BadgeDefinition>>{};
    for (final def in catalog) {
      groups.putIfAbsent(def.category, () => []).add(def);
    }
    return groups;
  }

  @override
  List<Object?> get props => [earned, catalog];
}

class EarnedBadge extends Equatable {
  const EarnedBadge({
    required this.badgeKey,
    required this.name,
    required this.category,
    required this.tier,
    this.period,
    this.earnedAt,
    this.threshold = 0,
  });

  final String badgeKey;
  final String name;
  final String category;
  final String tier;

  /// `YYYY-MM` for monthly badges, `YYYY` for yearly, empty otherwise.
  final String? period;
  final String? earnedAt;
  final int threshold;

  /// `"2026-07"` → `"July 2026 Daily Challenge"`.
  String get dailyChallengeName {
    final raw = period ?? '';
    final parts = raw.split('-');
    if (parts.length != 2) return name;
    final year = parts[0];
    final month = int.tryParse(parts[1]);
    if (month == null || month < 1 || month > 12) return name;
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[month - 1]} $year Daily Challenge';
  }

  @override
  List<Object?> get props =>
      [badgeKey, name, category, tier, period, earnedAt, threshold];
}

class BadgeDefinition extends Equatable {
  const BadgeDefinition({
    required this.key,
    required this.name,
    required this.description,
    required this.category,
    required this.tier,
    this.threshold = 0,
  });

  /// One completed daily-challenge month, promoted to its own catalog entry.
  ///
  /// The catalog ships a single locked template for `daily_perfect_month`, but
  /// the badge recurs — a student earns July *and* June — so each earned month
  /// is synthesised into a definition of its own. The key is suffixed with the
  /// period to keep those cards distinct, and the name is derived from the
  /// period rather than copied, because older rows were stored under a generic
  /// name.
  factory BadgeDefinition.fromDailyEarned(EarnedBadge badge) => BadgeDefinition(
        key: '${badge.badgeKey}:${badge.period ?? ''}',
        name: badge.dailyChallengeName,
        description: 'Completed every daily challenge this month',
        category: BadgeCategory.dailyChallenge,
        tier: badge.tier.isEmpty ? 'gold' : badge.tier,
        threshold: 1,
      );

  final String key;
  final String name;
  final String description;
  final String category;
  final String tier;
  final int threshold;

  @override
  List<Object?> get props => [key, name, description, category, tier, threshold];
}

/// Category keys and their presentation, from the web's `badge-visuals.ts`.
class BadgeCategory {
  const BadgeCategory._();

  static const streak = 'streak';
  static const monthly = 'monthly';
  static const yearly = 'yearly';
  static const accuracy = 'accuracy';
  static const dailyChallenge = 'daily_challenge';

  /// The single catalog entry that stands in for every completed month.
  static const dailyPerfectMonthKey = 'daily_perfect_month';

  static String label(String category) => switch (category) {
        streak => 'Daily Streak',
        monthly => 'Monthly Practice',
        yearly => 'Yearly Practice',
        accuracy => 'Accuracy',
        dailyChallenge => 'Daily Challenge',
        _ => category,
      };

  static IconData icon(String category) => switch (category) {
        streak || dailyChallenge => Icons.local_fire_department_rounded,
        monthly => Icons.calendar_month_rounded,
        yearly => Icons.military_tech_rounded,
        accuracy => Icons.my_location_rounded,
        _ => Icons.workspace_premium_rounded,
      };
}

/// Tier medallion gradients, from `TIER_COLOR`.
class BadgeTier {
  const BadgeTier._();

  static List<Color> gradient(String tier) => switch (tier) {
        'bronze' => const [Color(0xFFFB923C), Color(0xFFB45309)],
        'silver' => const [Color(0xFFCBD5E1), Color(0xFF64748B)],
        'gold' => const [Color(0xFFFCD34D), Color(0xFFCA8A04)],
        'platinum' => const [Color(0xFFA5F3FC), Color(0xFF0EA5E9)],
        'diamond' => const [Color(0xFF8B5CF6), Color(0xFFD961D2)],
        _ => const [Color(0xFF94A3B8), Color(0xFF64748B)],
      };

  /// The earned card's surface and chip tint, from `TIER_ACCENT`.
  ///
  /// A [TwShade] rather than raw colours, so `context.tokens.tone(...)` renders
  /// the web's `bg-<c>-500/15 text-<c>-700 dark:text-<c>-300` pair and picks up
  /// dark mode for free.
  static TwShade accent(String tier) => switch (tier) {
        'bronze' => TwColors.orange,
        'silver' => TwColors.slate,
        'gold' => TwColors.amber,
        // The web tints these `sky` and `chart-4`. `TwColors` has no sky, and
        // cyan is the nearest hue to it; fuchsia was added to the palette as
        // the stand-in for chart-4 (see `app_colors.dart`).
        'platinum' => TwColors.cyan,
        'diamond' => TwColors.fuchsia,
        _ => TwColors.slate,
      };
}
