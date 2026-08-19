import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:college_level/core/common/bloc/remote_cubit.dart';
import 'package:college_level/core/config/theme/app_colors.dart';
import 'package:college_level/core/constants/api_urls.dart';
import 'package:college_level/core/error/failures.dart';
import 'package:college_level/core/usecases/usecase.dart';
import 'package:college_level/features/badges/data/models/badge_model.dart';
import 'package:college_level/features/badges/domain/entities/badge.dart';
import 'package:college_level/features/badges/presentation/bloc/badges_cubit.dart';
import 'package:college_level/features/leaderboard/domain/usecases/leaderboard_usecases.dart';

class _MockGetBadges extends Mock implements GetBadgesUseCase {}

EarnedBadge _earned({
  String badgeKey = 'streak_bronze',
  String name = '3-Day Streak',
  String category = 'streak',
  String tier = 'bronze',
  String period = '',
  String? earnedAt = '2026-03-04T10:00:00.000Z',
}) =>
    EarnedBadge(
      badgeKey: badgeKey,
      name: name,
      category: category,
      tier: tier,
      period: period,
      earnedAt: earnedAt,
    );

BadgeDefinition _def({
  String key = 'streak_bronze',
  String name = '3-Day Streak',
  String category = 'streak',
  String tier = 'bronze',
}) =>
    BadgeDefinition(
      key: key,
      name: name,
      description: '$name description',
      category: category,
      tier: tier,
    );

void main() {
  setUpAll(() => registerFallbackValue(const NoParams()));

  group('BadgeCollection', () {
    /// Monthly and yearly badges recur per period, so the same key arrives more
    /// than once. The newest must win regardless of the order the rows land in.
    test('earnedByKey keeps the newest row per key', () {
      final collection = BadgeCollection(
        earned: [
          _earned(earnedAt: '2026-07-01T00:00:00.000Z', name: 'Newer'),
          _earned(earnedAt: '2026-01-01T00:00:00.000Z', name: 'Older'),
        ],
      );

      expect(collection.earnedByKey['streak_bronze']?.name, 'Newer');
    });

    test('dailyEarned sorts newest period first', () {
      final collection = BadgeCollection(
        earned: [
          _earned(
            badgeKey: 'daily_perfect_month',
            category: 'daily_challenge',
            period: '2026-06',
          ),
          _earned(
            badgeKey: 'daily_perfect_month',
            category: 'daily_challenge',
            period: '2026-08',
          ),
          _earned(
            badgeKey: 'daily_perfect_month',
            category: 'daily_challenge',
            period: '2026-07',
          ),
        ],
      );

      expect(
        collection.dailyEarned.map((b) => b.period).toList(),
        ['2026-08', '2026-07', '2026-06'],
      );
    });

    /// The daily badge is one catalog row but many earned months, so it is
    /// counted by month on both sides of the fraction rather than as one badge.
    test('counts swap the daily template for the months actually earned', () {
      final collection = BadgeCollection(
        earned: [
          _earned(),
          _earned(
            badgeKey: 'daily_perfect_month',
            category: 'daily_challenge',
            period: '2026-07',
          ),
          _earned(
            badgeKey: 'daily_perfect_month',
            category: 'daily_challenge',
            period: '2026-06',
          ),
        ],
        catalog: [
          _def(),
          _def(key: 'streak_gold', name: '30-Day Streak'),
          _def(
            key: 'daily_perfect_month',
            name: 'Monthly Completion',
            category: 'daily_challenge',
          ),
        ],
      );

      // One streak badge + two completed months.
      expect(collection.earnedCount, 3);
      // Two fixed catalog entries + the same two months.
      expect(collection.totalCount, 4);
      expect(collection.progressPercent, 75);
    });

    test('progressPercent is zero rather than NaN on an empty catalog', () {
      expect(const BadgeCollection().progressPercent, 0);
      expect(const BadgeCollection().totalCount, 0);
    });

    test('progressPercent rounds', () {
      final collection = BadgeCollection(
        earned: [_earned()],
        catalog: [
          _def(),
          _def(key: 'b', name: 'B'),
          _def(key: 'c', name: 'C'),
        ],
      );

      expect(collection.progressPercent, 33);
    });

    /// Section order on the page is catalog order, so the grouping must not
    /// sort — feeding accuracy first has to come back first.
    test('grouped preserves catalog order rather than sorting', () {
      final collection = BadgeCollection(
        catalog: [
          _def(key: 'sharpshooter', name: 'Sharpshooter', category: 'accuracy'),
          _def(key: 'monthly_bronze', name: 'Monthly', category: 'monthly'),
          _def(key: 'streak_bronze', name: 'Streak', category: 'streak'),
        ],
      );

      expect(
        collection.grouped.keys.toList(),
        ['accuracy', 'monthly', 'streak'],
      );
    });
  });

  group('EarnedBadge.dailyChallengeName', () {
    test('a period becomes a month label', () {
      expect(
        _earned(period: '2026-07').dailyChallengeName,
        'July 2026 Daily Challenge',
      );
    });

    /// Older rows carry a generic name and a malformed or absent period; the
    /// stored name is the only thing left to show.
    test('an unusable period falls back to the stored name', () {
      for (final period in [null, '', '2026', '2026-13', '2026-00', 'nope']) {
        expect(
          _earned(period: period ?? '', name: 'Perfect Month')
              .dailyChallengeName,
          'Perfect Month',
          reason: 'period: $period',
        );
      }
    });
  });

  group('BadgeDefinition.fromDailyEarned', () {
    test('the key is suffixed with the period to keep months distinct', () {
      final definition = BadgeDefinition.fromDailyEarned(
        _earned(
          badgeKey: 'daily_perfect_month',
          category: 'daily_challenge',
          period: '2026-07',
        ),
      );

      expect(definition.key, 'daily_perfect_month:2026-07');
      expect(definition.name, 'July 2026 Daily Challenge');
      expect(definition.category, BadgeCategory.dailyChallenge);
      expect(definition.description, 'Completed every daily challenge this month');
      expect(definition.threshold, 1);
    });

    test('a missing tier becomes gold', () {
      expect(BadgeDefinition.fromDailyEarned(_earned(tier: '')).tier, 'gold');
    });
  });

  group('BadgeTier', () {
    test('gradients are pinned per tier', () {
      expect(BadgeTier.gradient('bronze').first.toARGB32(), 0xFFFB923C);
      expect(BadgeTier.gradient('gold').first.toARGB32(), 0xFFFCD34D);
      expect(BadgeTier.gradient('diamond').last.toARGB32(), 0xFFD961D2);
    });

    test('an unknown tier falls back to slate rather than throwing', () {
      expect(BadgeTier.gradient('mythic').first.toARGB32(), 0xFF94A3B8);
      expect(BadgeTier.accent('mythic'), TwColors.slate);
    });

    test('accents map each tier to its palette', () {
      expect(BadgeTier.accent('bronze'), TwColors.orange);
      expect(BadgeTier.accent('silver'), TwColors.slate);
      expect(BadgeTier.accent('gold'), TwColors.amber);
      expect(BadgeTier.accent('platinum'), TwColors.cyan);
      expect(BadgeTier.accent('diamond'), TwColors.fuchsia);
    });
  });

  group('BadgeCategory', () {
    test('known categories get their web labels', () {
      expect(BadgeCategory.label('streak'), 'Daily Streak');
      expect(BadgeCategory.label('monthly'), 'Monthly Practice');
      expect(BadgeCategory.label('yearly'), 'Yearly Practice');
      expect(BadgeCategory.label('accuracy'), 'Accuracy');
      expect(BadgeCategory.label('daily_challenge'), 'Daily Challenge');
    });

    /// The catalog lives in backend code, so a new category can ship without
    /// the app — it must render as itself rather than blank.
    test('an unknown category is its own label', () {
      expect(BadgeCategory.label('contest_streak'), 'contest_streak');
    });
  });

  group('BadgeCollectionModel', () {
    test('parses a full payload', () {
      final collection = BadgeCollectionModel.fromJson(const {
        'earned': [
          {
            'badgeKey': 'streak_bronze',
            'name': '3-Day Streak',
            'category': 'streak',
            'tier': 'bronze',
            'period': '',
            'earnedAt': '2026-03-04T10:00:00.000Z',
            'threshold': 3,
          },
        ],
        'catalog': [
          {
            'key': 'streak_bronze',
            'name': '3-Day Streak',
            'description': 'Practice 3 days in a row',
            'category': 'streak',
            'tier': 'bronze',
            'threshold': 3,
          },
        ],
      });

      expect(collection.earned.single.badgeKey, 'streak_bronze');
      expect(collection.earned.single.threshold, 3);
      expect(collection.catalog.single.description, 'Practice 3 days in a row');
    });

    test('an empty payload yields empty lists rather than throwing', () {
      final collection = BadgeCollectionModel.fromJson(const {});

      expect(collection.earned, isEmpty);
      expect(collection.catalog, isEmpty);
      expect(collection.progressPercent, 0);
    });

    /// Daily-challenge rows are written by a different service and have been
    /// seen without a tier.
    test('a row with no tier parses as gold', () {
      final collection = BadgeCollectionModel.fromJson(const {
        'earned': [
          {'badgeKey': 'daily_perfect_month', 'category': 'daily_challenge'},
        ],
      });

      expect(collection.earned.single.tier, 'gold');
    });

    test('non-object entries are dropped', () {
      final collection = BadgeCollectionModel.fromJson(const {
        'earned': ['nope', 42, null],
        'catalog': 'not a list',
      });

      expect(collection.earned, isEmpty);
      expect(collection.catalog, isEmpty);
    });
  });

  group('BadgesCubit', () {
    late _MockGetBadges getBadges;

    setUp(() => getBadges = _MockGetBadges());

    test('a success carries the collection', () async {
      final collection = BadgeCollection(catalog: [_def()]);
      when(() => getBadges(any()))
          .thenAnswer((_) async => Right<Failure, BadgeCollection>(collection));

      final cubit = BadgesCubit(getBadges: getBadges);
      await cubit.load();

      expect(cubit.state.status, RemoteStatus.success);
      expect(cubit.state.data, collection);
    });

    test('a failure leaves no data behind', () async {
      when(() => getBadges(any())).thenAnswer(
        (_) async =>
            const Left<Failure, BadgeCollection>(NetworkFailure('offline')),
      );

      final cubit = BadgesCubit(getBadges: getBadges);
      await cubit.load();

      expect(cubit.state.status, RemoteStatus.failure);
      expect(cubit.state.failure, isA<NetworkFailure>());
      expect(cubit.state.data, isNull);
    });

    test('a refresh replaces the collection', () async {
      when(() => getBadges(any())).thenAnswer(
        (_) async => Right<Failure, BadgeCollection>(
          BadgeCollection(catalog: [_def()]),
        ),
      );

      final cubit = BadgesCubit(getBadges: getBadges);
      await cubit.load();

      when(() => getBadges(any())).thenAnswer(
        (_) async => Right<Failure, BadgeCollection>(
          BadgeCollection(catalog: [_def(), _def(key: 'b', name: 'B')]),
        ),
      );
      await cubit.load(refresh: true);

      expect(cubit.state.data?.catalog, hasLength(2));
    });
  });

  test('the badges endpoint is the student practice one', () {
    expect(ApiUrls.practiceBadges, '/student/practice/badges');
  });
}
