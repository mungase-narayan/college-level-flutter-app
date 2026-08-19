import 'package:dartz/dartz.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:college_level/core/common/bloc/remote_cubit.dart';
import 'package:college_level/core/constants/api_urls.dart';
import 'package:college_level/core/error/failures.dart';
import 'package:college_level/core/network/api_response.dart';
import 'package:college_level/core/usecases/usecase.dart';
import 'package:college_level/features/rating/data/models/contest_rating_model.dart';
import 'package:college_level/features/rating/domain/entities/contest_rating.dart';
import 'package:college_level/features/rating/domain/usecases/get_my_rating_usecase.dart';
import 'package:college_level/features/rating/presentation/bloc/rating_cubit.dart';
import 'package:college_level/features/rating/presentation/bloc/rating_leaderboard_cubit.dart';

class _MockGetMyRating extends Mock implements GetMyRatingUseCase {}

class _MockGetLeaderboard extends Mock implements GetRatingLeaderboardUseCase {}

RatingLeaderboard _board({
  List<RatingLeaderboardEntry> entries = const [],
  int? myRank,
  int page = 1,
  int totalPages = 1,
}) =>
    RatingLeaderboard(
      entries: entries,
      myRank: myRank,
      pagination: Pagination(
        page: page,
        limit: 20,
        total: entries.length,
        totalPages: totalPages,
      ),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(const RatingLeaderboardParams());
  });

  group('ContestRatingModel', () {
    test('a full payload parses', () {
      final rating = ContestRatingModel.fromJson(const {
        'rating': 1543,
        'peakRating': 1580,
        'contestsPlayed': 7,
        'tier': 'Specialist',
        'tierColor': '#03a89e',
        'isProvisional': false,
        'history': [
          {
            'contestId': 'c1',
            'contestTitle': 'Spring Open',
            'endAt': '2026-03-05T12:00:00.000Z',
            'rank': 8,
            'participants': 154,
            'ratingBefore': 1500,
            'ratingAfter': 1543,
            'ratingDelta': 43,
          },
        ],
      });

      expect(rating.rating, 1543);
      expect(rating.peakRating, 1580);
      expect(rating.tier, 'Specialist');
      expect(rating.color, const Color(0xFF03A89E));
      expect(rating.isProvisional, isFalse);
      expect(rating.history.single.contestTitle, 'Spring Open');
      expect(rating.history.single.ratingDelta, 43);
    });

    /// A student who has never competed still gets a page, not an error.
    test('an empty payload falls back to the starting rating', () {
      final rating = ContestRatingModel.fromJson(const {});

      expect(rating.rating, RatingTier.defaultRating);
      expect(rating.peakRating, RatingTier.defaultRating);
      expect(rating.contestsPlayed, 0);
      expect(rating.tier, 'Pupil');
      expect(rating.history, isEmpty);
    });

    test('a null delta survives as null rather than zero', () {
      final rating = ContestRatingModel.fromJson(const {
        'history': [
          {'contestId': 'c1', 'contestTitle': 'Unrated'},
        ],
      });

      final entry = rating.history.single;
      expect(entry.ratingDelta, isNull);
      expect(entry.ratingAfter, isNull);
      expect(entry.rank, isNull);
    });

    /// The curve depends on the order, so it must survive parsing untouched.
    test('history order is preserved oldest-first', () {
      final rating = ContestRatingModel.fromJson(const {
        'history': [
          {'contestId': 'a', 'contestTitle': 'First', 'ratingAfter': 1200},
          {'contestId': 'b', 'contestTitle': 'Second', 'ratingAfter': 1250},
          {'contestId': 'c', 'contestTitle': 'Third', 'ratingAfter': 1300},
        ],
      });

      expect(
        rating.history.map((h) => h.contestTitle),
        ['First', 'Second', 'Third'],
      );
    });
  });

  group('ContestRating.bestGain', () {
    ContestRating withDeltas(List<int?> deltas) => ContestRating(
          rating: 1200,
          peakRating: 1200,
          contestsPlayed: deltas.length,
          tier: 'Pupil',
          tierColor: '#008000',
          isProvisional: false,
          history: [
            for (final delta in deltas)
              RatingHistoryEntry(
                contestId: 'c',
                contestTitle: 't',
                ratingDelta: delta,
              ),
          ],
        );

    test('is the largest positive gain', () {
      expect(withDeltas([12, 43, -8, 30]).bestGain, 43);
    });

    /// "Best gain" of a loss is not a gain — the footer should be omitted.
    test('is null when every result was a loss', () {
      expect(withDeltas([-5, -20]).bestGain, isNull);
    });

    test('is null with no history at all', () {
      expect(withDeltas(const []).bestGain, isNull);
    });
  });

  group('RatingTier', () {
    test('resolves at every boundary', () {
      expect(RatingTier.resolve(2400).name, 'Grandmaster');
      expect(RatingTier.resolve(2399).name, 'International Master');
      expect(RatingTier.resolve(1600).name, 'Expert');
      expect(RatingTier.resolve(1200).name, 'Pupil');
      expect(RatingTier.resolve(1199).name, 'Newbie');
      expect(RatingTier.resolve(0).name, 'Newbie');
    });

    test('the ladder is complete', () {
      expect(RatingTier.all, hasLength(8));
      expect(RatingTier.defaultRating, 1200);
    });

    test('parses a hex colour and rejects a malformed one', () {
      expect(RatingTier.parseHex('#03a89e'), const Color(0xFF03A89E));
      expect(RatingTier.parseHex('03a89e'), const Color(0xFF03A89E));
      expect(RatingTier.parseHex('#xyz'), isNull);
      expect(RatingTier.parseHex(null), isNull);
    });
  });

  group('RatingLeaderboardModel', () {
    test('a full payload parses', () {
      final board = RatingLeaderboardModel.fromJson(const {
        'entries': [
          {
            'studentId': 's1',
            'rating': 1543,
            'peakRating': 1580,
            'contestsPlayed': 7,
            'name': 'Asha Rao',
            'username': 'asha',
            'avatarUrl': null,
            'rollNumber': 'CS-14',
            'rank': 1,
            'tier': 'Specialist',
            'tierColor': '#03a89e',
            'isCurrentUser': true,
          },
        ],
        'myRank': 12,
        'pagination': {'page': 1, 'limit': 20, 'total': 137, 'totalPages': 7},
      });

      expect(board.entries.single.name, 'Asha Rao');
      expect(board.entries.single.isCurrentUser, isTrue);
      expect(board.entries.single.color, const Color(0xFF03A89E));
      expect(board.myRank, 12);
      expect(board.pagination.totalPages, 7);
    });

    /// An unranked student has no rank at all. Zero would render as "#0".
    test('a null myRank stays null', () {
      final board = RatingLeaderboardModel.fromJson(const {'myRank': null});

      expect(board.myRank, isNull);
    });

    test('an empty payload is survivable', () {
      final board = RatingLeaderboardModel.fromJson(const {});

      expect(board.entries, isEmpty);
      expect(board.myRank, isNull);
      expect(board.pagination.page, 1);
    });

    test('a row that is not the current user is not flagged', () {
      final board = RatingLeaderboardModel.fromJson(const {
        'entries': [
          {'studentId': 's2', 'rating': 1300, 'isCurrentUser': false},
        ],
      });

      expect(board.entries.single.isCurrentUser, isFalse);
      // The tier falls back to the local ladder when the server omits it.
      expect(board.entries.single.tier, 'Pupil');
    });
  });

  group('RatingLeaderboardParams', () {
    test('defaults match the web', () {
      const params = RatingLeaderboardParams();

      expect(params.page, 1);
      expect(params.limit, 20);
    });

    test('copyWith keeps the limit', () {
      expect(const RatingLeaderboardParams().copyWith(page: 3).limit, 20);
    });
  });

  group('RatingCubit', () {
    late _MockGetMyRating getMyRating;

    setUp(() => getMyRating = _MockGetMyRating());

    test('a success carries the rating', () async {
      when(() => getMyRating(any())).thenAnswer(
        (_) async => Right<Failure, ContestRating>(
          ContestRatingModel.fromJson(const {'rating': 1543}),
        ),
      );

      final cubit = RatingCubit(getMyRating: getMyRating);
      await cubit.load();

      expect(cubit.state.status, RemoteStatus.success);
      expect(cubit.state.data?.rating, 1543);
    });

    test('a failure is surfaced', () async {
      when(() => getMyRating(any())).thenAnswer(
        (_) async => const Left<Failure, ContestRating>(NetworkFailure('down')),
      );

      final cubit = RatingCubit(getMyRating: getMyRating);
      await cubit.load();

      expect(cubit.state.status, RemoteStatus.failure);
      expect(cubit.state.data, isNull);
    });
  });

  group('RatingLeaderboardCubit', () {
    late _MockGetLeaderboard getLeaderboard;

    setUp(() => getLeaderboard = _MockGetLeaderboard());

    test('setPage requests that page', () async {
      when(() => getLeaderboard(any())).thenAnswer(
        (_) async => Right<Failure, RatingLeaderboard>(_board(page: 2)),
      );

      final cubit = RatingLeaderboardCubit(getRatingLeaderboard: getLeaderboard);
      await cubit.setPage(2);

      expect(cubit.params.page, 2);
      verify(() => getLeaderboard(const RatingLeaderboardParams(page: 2)))
          .called(1);
    });

    /// A dropped page should dim the list, not replace a good standing.
    test('a failure keeps the rows already on screen', () async {
      when(() => getLeaderboard(any())).thenAnswer(
        (_) async => Right<Failure, RatingLeaderboard>(
          _board(entries: const [
            RatingLeaderboardEntry(
              studentId: 's1',
              rank: 1,
              rating: 1500,
              peakRating: 1500,
              contestsPlayed: 3,
              name: 'Asha',
              username: 'asha',
              tier: 'Specialist',
              tierColor: '#03a89e',
            ),
          ]),
        ),
      );

      final cubit = RatingLeaderboardCubit(getRatingLeaderboard: getLeaderboard);
      await cubit.load();

      when(() => getLeaderboard(any())).thenAnswer(
        (_) async =>
            const Left<Failure, RatingLeaderboard>(NetworkFailure('offline')),
      );
      await cubit.setPage(2);

      expect(cubit.state.status, RemoteStatus.failure);
      expect(cubit.state.data?.entries, hasLength(1));
    });

    test('re-requesting the current page does nothing', () async {
      when(() => getLeaderboard(any())).thenAnswer(
        (_) async => Right<Failure, RatingLeaderboard>(_board()),
      );

      final cubit = RatingLeaderboardCubit(getRatingLeaderboard: getLeaderboard);
      await cubit.setPage(1);

      verifyNever(() => getLeaderboard(any()));
    });
  });

  test('the rating endpoints match the backend router', () {
    expect(ApiUrls.contestRatingMe, '/student/contest-ratings/me');
    expect(
      ApiUrls.contestRatingLeaderboard,
      '/student/contest-ratings/leaderboard',
    );
  });
}
