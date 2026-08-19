import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:college_level/core/common/bloc/remote_cubit.dart';
import 'package:college_level/core/config/theme/app_colors.dart';
import 'package:college_level/core/constants/api_urls.dart';
import 'package:college_level/core/error/failures.dart';
import 'package:college_level/core/network/api_response.dart';
import 'package:college_level/features/leaderboard/data/models/leaderboard_model.dart';
import 'package:college_level/features/leaderboard/domain/entities/leaderboard.dart';
import 'package:college_level/features/leaderboard/domain/usecases/leaderboard_usecases.dart';
import 'package:college_level/features/leaderboard/presentation/bloc/leaderboard_cubit.dart';

class _MockGetLeaderboard extends Mock implements GetLeaderboardUseCase {}

LeaderboardStandings _standings({
  List<LeaderboardRow> rows = const [],
  LeaderboardMe? me,
  int page = 1,
  int totalPages = 1,
  String scope = LeaderboardScope.school,
  String period = LeaderboardPeriod.allTime,
}) =>
    LeaderboardStandings(
      rows: rows,
      pagination: Pagination(
        page: page,
        limit: 20,
        total: rows.length,
        totalPages: totalPages,
      ),
      me: me,
      scope: scope,
      period: period,
    );

void main() {
  setUpAll(() => registerFallbackValue(const LeaderboardParams()));

  group('LeaderboardRowModel', () {
    /// The regression test for the bug this screen was built on top of: the
    /// server field is `isCurrentUser`, and reading `isMe` instead silently
    /// disabled the highlight that marks the reader's own row.
    test('isCurrentUser drives isMe', () {
      final row = LeaderboardRowModel.fromJson(const {
        'rank': 4,
        'points': 120,
        'solved': 30,
        'isCurrentUser': true,
      });

      expect(row.isMe, isTrue);
    });

    test('a row that is not the current user is not flagged', () {
      final row = LeaderboardRowModel.fromJson(const {
        'rank': 5,
        'points': 10,
        'solved': 2,
        'isCurrentUser': false,
      });

      expect(row.isMe, isFalse);
    });

    /// `isMe` is the entity's name, not the wire's. If someone "fixes" the key
        /// to match the field, this fails.
    test('an isMe key on the wire is ignored', () {
      final row = LeaderboardRowModel.fromJson(const {
        'rank': 1,
        'points': 1,
        'solved': 1,
        'isMe': true,
      });

      expect(row.isMe, isFalse);
    });

    test('a full row parses', () {
      final row = LeaderboardRowModel.fromJson(const {
        'rank': 2,
        'points': 340,
        'solved': 88,
        'studentId': 's1',
        'username': 'asha',
        'fullName': 'Asha Rao',
        'avatar': 'https://example.com/a.png',
        'rollNumber': 'CS-014',
        'accuracy': 91,
        'badgeCount': 3,
        'isCurrentUser': false,
      });

      expect(row.rank, 2);
      expect(row.displayName, 'Asha Rao');
      expect(row.rollNumber, 'CS-014');
      expect(row.accuracy, 91);
      expect(row.badgeCount, 3);
    });

    /// Null accuracy means "never attempted". Coercing it to 0 would claim the
    /// student got everything wrong.
    test('a missing accuracy stays null rather than becoming zero', () {
      final row = LeaderboardRowModel.fromJson(const {
        'rank': 9,
        'points': 0,
        'solved': 0,
      });

      expect(row.accuracy, isNull);
      expect(row.points, 0);
    });

    test('a nameless row falls back to an em dash', () {
      final row = LeaderboardRowModel.fromJson(const {'rank': 1});

      expect(row.displayName, '—');
    });
  });

  group('LeaderboardStandingsModel', () {
    test('a full payload parses', () {
      final standings = LeaderboardStandingsModel.fromJson(const {
        'data': [
          {'rank': 1, 'points': 500, 'solved': 100, 'fullName': 'Top'},
        ],
        'pagination': {'page': 1, 'limit': 20, 'total': 1, 'totalPages': 1},
        'me': {'rank': 4, 'points': 120, 'solved': 30, 'accuracy': 77},
        'scope': 'batch',
        'period': 'weekly',
      });

      expect(standings.rows.single.displayName, 'Top');
      expect(standings.me?.rank, 4);
      expect(standings.me?.accuracy, 77);
      expect(standings.scope, 'batch');
      expect(standings.period, 'weekly');
    });

    /// `me` is null until the student has solved something — a real state, not
    /// an error, and the banner has to stay hidden for it.
    test('a null me stays null', () {
      final standings = LeaderboardStandingsModel.fromJson(const {
        'data': [],
        'me': null,
      });

      expect(standings.me, isNull);
      expect(standings.rows, isEmpty);
    });

    test('an empty payload falls back to sane defaults', () {
      final standings = LeaderboardStandingsModel.fromJson(const {});

      expect(standings.rows, isEmpty);
      expect(standings.me, isNull);
      expect(standings.scope, LeaderboardScope.school);
      expect(standings.period, LeaderboardPeriod.defaultPeriod);
    });

    test("me's accuracy can be null", () {
      final standings = LeaderboardStandingsModel.fromJson(const {
        'me': {'rank': 12, 'points': 0, 'solved': 0},
      });

      expect(standings.me?.accuracy, isNull);
      expect(standings.me?.rank, 12);
    });
  });

  group('labels', () {
    test('every scope has a label', () {
      expect(LeaderboardScope.label('school'), 'School');
      expect(LeaderboardScope.label('batch'), 'Batch');
      expect(LeaderboardScope.label('department'), 'Department');
      expect(LeaderboardScope.options, hasLength(3));
    });

    test('every period has a label', () {
      expect(LeaderboardPeriod.label('today'), 'Today');
      expect(LeaderboardPeriod.label('weekly'), 'This week');
      expect(LeaderboardPeriod.label('monthly'), 'This month');
      expect(LeaderboardPeriod.label('yearly'), 'This year');
      expect(LeaderboardPeriod.label('all_time'), 'All time');
      expect(LeaderboardPeriod.options, hasLength(5));
    });

    /// The API accepts `semester` too; if the UI ever surfaces it, it must not
    /// render as a blank chip.
    test('an unknown value renders as itself', () {
      expect(LeaderboardScope.label('semester'), 'semester');
      expect(LeaderboardPeriod.label('fortnightly'), 'fortnightly');
    });
  });

  group('rankShade', () {
    test('the top three take medal tints and the rest go neutral', () {
      expect(rankShade(1), TwColors.amber);
      expect(rankShade(2), TwColors.slate);
      expect(rankShade(3), TwColors.orange);
      expect(rankShade(4), TwColors.slate);
      expect(rankShade(97), TwColors.slate);
    });
  });

  group('LeaderboardParams', () {
    /// A filter change must restart at page 1, or the reader lands on page 4 of
    /// a board they have not seen the top of.
    test('changing scope or period resets to page 1', () {
      const params = LeaderboardParams(page: 4);

      expect(params.copyWith(scope: 'batch').page, 1);
      expect(params.copyWith(period: 'today').page, 1);
    });

    test('an explicit page is honoured', () {
      const params = LeaderboardParams();

      expect(params.copyWith(page: 3).page, 3);
    });

    test('the defaults match the web', () {
      const params = LeaderboardParams();

      expect(params.scope, LeaderboardScope.school);
      expect(params.period, LeaderboardPeriod.allTime);
      expect(params.page, 1);
      expect(params.limit, 20);
    });
  });

  group('LeaderboardCubit', () {
    late _MockGetLeaderboard getLeaderboard;

    setUp(() => getLeaderboard = _MockGetLeaderboard());

    void stub(LeaderboardStandings value) {
      when(() => getLeaderboard(any())).thenAnswer(
        (_) async => Right<Failure, LeaderboardStandings>(value),
      );
    }

    test('a success carries the standings', () async {
      stub(_standings(me: const LeaderboardMe(rank: 4, points: 1, solved: 1)));

      final cubit = LeaderboardCubit(getLeaderboard: getLeaderboard);
      await cubit.load();

      expect(cubit.state.status, RemoteStatus.success);
      expect(cubit.state.data?.me?.rank, 4);
    });

    /// The last good standings are real; a dropped request should dim them, not
    /// replace them with an error screen.
    test('a failure keeps the rows already on screen', () async {
      stub(_standings(rows: [
        const LeaderboardRow(rank: 1, points: 10, solved: 2, fullName: 'A'),
      ]));

      final cubit = LeaderboardCubit(getLeaderboard: getLeaderboard);
      await cubit.load();

      when(() => getLeaderboard(any())).thenAnswer(
        (_) async =>
            const Left<Failure, LeaderboardStandings>(NetworkFailure('offline')),
      );
      await cubit.load();

      expect(cubit.state.status, RemoteStatus.failure);
      expect(cubit.state.data?.rows, hasLength(1));
    });

    test('setScope refetches from page 1 with the new scope', () async {
      stub(_standings());

      final cubit = LeaderboardCubit(getLeaderboard: getLeaderboard);
      await cubit.setPage(3);
      await cubit.setScope('batch');

      expect(cubit.params.scope, 'batch');
      expect(cubit.params.page, 1);
      verify(() => getLeaderboard(
            const LeaderboardParams(scope: 'batch'),
          )).called(1);
    });

    test('setPeriod refetches from page 1', () async {
      stub(_standings());

      final cubit = LeaderboardCubit(getLeaderboard: getLeaderboard);
      await cubit.setPage(2);
      await cubit.setPeriod('today');

      expect(cubit.params.period, 'today');
      expect(cubit.params.page, 1);
    });

    test('setPage requests that page', () async {
      stub(_standings(page: 2));

      final cubit = LeaderboardCubit(getLeaderboard: getLeaderboard);
      await cubit.setPage(2);

      verify(() => getLeaderboard(const LeaderboardParams(page: 2))).called(1);
    });

    /// Re-tapping the active chip should not spend a request.
    test('setting an unchanged filter does nothing', () async {
      stub(_standings());

      final cubit = LeaderboardCubit(getLeaderboard: getLeaderboard);
      await cubit.setScope(LeaderboardScope.school);
      await cubit.setPeriod(LeaderboardPeriod.allTime);
      await cubit.setPage(1);

      verifyNever(() => getLeaderboard(any()));
    });
  });

  test('the leaderboard endpoint matches the backend router', () {
    expect(ApiUrls.practiceLeaderboard, '/student/practice/leaderboard');
  });
}
