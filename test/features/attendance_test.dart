import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:college_level/core/common/bloc/remote_cubit.dart';
import 'package:college_level/core/config/theme/app_colors.dart';
import 'package:college_level/core/error/failures.dart';
import 'package:college_level/core/network/api_response.dart';
import 'package:college_level/core/usecases/usecase.dart';
import 'package:college_level/core/utils/formatters.dart';
import 'package:college_level/features/attendance/data/models/attendance_model.dart';
import 'package:college_level/features/attendance/domain/entities/attendance.dart';
import 'package:college_level/features/attendance/domain/usecases/attendance_usecases.dart';
import 'package:college_level/features/attendance/presentation/bloc/attendance_overview_cubit.dart';
import 'package:college_level/features/attendance/presentation/bloc/attendance_sessions_cubit.dart';

class _MockListSessions extends Mock implements ListAttendanceSessionsUseCase {}

class _MockGetOverall extends Mock implements GetOverallAttendanceUseCase {}

AttendanceSession _session(String id) => AttendanceSession(
      id: id,
      status: 'present',
      type: 'lecture',
      sessionDate: '2026-08-02',
      courseCode: 'CS201',
    );

Paginated<AttendanceSession> _page({
  required int page,
  required int totalPages,
  int items = 2,
}) =>
    Paginated<AttendanceSession>(
      items: [for (var i = 0; i < items; i++) _session('$page-$i')],
      pagination: Pagination(
        page: page,
        limit: 10,
        total: totalPages * items,
        totalPages: totalPages,
      ),
    );

void main() {
  late _MockListSessions listSessions;
  late AttendanceSessionsCubit cubit;

  List<AttendanceSessionParams> capturedParams() =>
      verify(() => listSessions(captureAny()))
          .captured
          .cast<AttendanceSessionParams>();

  setUpAll(() {
    registerFallbackValue(const AttendanceSessionParams());
    registerFallbackValue(const NoParams());
  });

  setUp(() {
    listSessions = _MockListSessions();
    when(() => listSessions(any())).thenAnswer(
      (_) async =>
          Right<Failure, Paginated<AttendanceSession>>(_page(page: 1, totalPages: 1)),
    );
    cubit = AttendanceSessionsCubit(listSessions: listSessions);
  });

  tearDown(() => cubit.close());

  group('AttendanceSessionsCubit', () {
    /// The backend defaults `limit` to 20; the web pins it to 10. Losing this
    /// silently doubles the page size.
    test('every request asks for ten rows', () async {
      await cubit.load();
      await cubit.setFilters(status: 'absent');

      expect(capturedParams().map((p) => p.limit), everyElement(10));
    });

    test('course and status are applied in a single request', () async {
      await cubit.setFilters(courseId: 'c1', status: 'absent');

      final params = capturedParams();
      expect(params, hasLength(1));
      expect(params.single.courseId, 'c1');
      expect(params.single.status, 'absent');
    });

    /// Pins `clearCourseId`. Without it `copyWith`'s `??` swallows the null and
    /// the course filter can be set but never cleared.
    test('clearing both filters actually clears them', () async {
      await cubit.setFilters(courseId: 'c1', status: 'absent');
      await cubit.setFilters();

      final last = capturedParams().last;
      expect(last.courseId, isNull);
      expect(last.status, isNull);
      expect(last.hasFilters, isFalse);
    });

    test('one filter can be cleared while the other stays', () async {
      await cubit.setFilters(courseId: 'c1', status: 'absent');
      await cubit.setFilters(courseId: 'c1');

      final last = capturedParams().last;
      expect(last.courseId, 'c1');
      expect(last.status, isNull);
      expect(last.activeFilterCount, 1);
    });

    test('a filter change restarts at the first page', () async {
      when(() => listSessions(any())).thenAnswer(
        (invocation) async {
          final params =
              invocation.positionalArguments.first as AttendanceSessionParams;
          return Right<Failure, Paginated<AttendanceSession>>(
            _page(page: params.page, totalPages: 3),
          );
        },
      );

      await cubit.load();
      await cubit.loadMore();
      await cubit.setFilters(status: 'late');

      expect(capturedParams().last.page, 1);
    });

    test('loadMore appends the next page rather than replacing it', () async {
      when(() => listSessions(any())).thenAnswer(
        (invocation) async {
          final params =
              invocation.positionalArguments.first as AttendanceSessionParams;
          return Right<Failure, Paginated<AttendanceSession>>(
            _page(page: params.page, totalPages: 2),
          );
        },
      );

      await cubit.load();
      await cubit.loadMore();

      expect(cubit.state.data!.items, hasLength(4));
      expect(capturedParams().map((p) => p.page), [1, 2]);
    });

    test('loadMore stops at the last page', () async {
      await cubit.load();
      await cubit.loadMore();
      await cubit.loadMore();

      verify(() => listSessions(any())).called(1);
    });

    test('a second loadMore while one is in flight is ignored', () async {
      final gate = Completer<Either<Failure, Paginated<AttendanceSession>>>();
      when(() => listSessions(any())).thenAnswer(
        (invocation) {
          final params =
              invocation.positionalArguments.first as AttendanceSessionParams;
          if (params.page == 1) {
            return Future.value(
              Right<Failure, Paginated<AttendanceSession>>(
                _page(page: 1, totalPages: 3),
              ),
            );
          }
          return gate.future;
        },
      );

      await cubit.load();
      final first = cubit.loadMore();
      await cubit.loadMore();
      gate.complete(
        Right<Failure, Paginated<AttendanceSession>>(_page(page: 2, totalPages: 3)),
      );
      await first;

      verify(() => listSessions(any())).called(2);
    });

    /// A failed "load more" must not throw away the pages already on screen —
    /// the footer simply stops advancing.
    test('a failed loadMore keeps what is already listed', () async {
      var call = 0;
      when(() => listSessions(any())).thenAnswer((_) async {
        call++;
        if (call == 1) {
          return Right<Failure, Paginated<AttendanceSession>>(
            _page(page: 1, totalPages: 3),
          );
        }
        return const Left<Failure, Paginated<AttendanceSession>>(
          NetworkFailure('offline'),
        );
      });

      await cubit.load();
      await cubit.loadMore();

      expect(cubit.state.data!.items, hasLength(2));
      expect(cubit.state.failure, isNotNull);
    });
  });

  group('AttendanceOverviewCubit', () {
    test('exposes the overall analytics', () async {
      final getOverall = _MockGetOverall();
      when(() => getOverall(any())).thenAnswer(
        (_) async => Right<Failure, AttendanceOverview>(
          const AttendanceOverview(
            overall: CourseAttendance(
              totalSessions: 50,
              percentage: 82,
              counts: AttendanceCounts(present: 41, absent: 6, late: 2, leave: 1),
            ),
            courses: [],
          ),
        ),
      );

      final overview = AttendanceOverviewCubit(getOverall: getOverall);
      addTearDown(overview.close);
      await overview.load();

      expect(overview.state.status, RemoteStatus.success);
      expect(overview.state.data!.overall.percentage, 82);
    });

    /// The reason the screen runs two cubits: the analytics aggregate failing
    /// must leave the session list alone.
    test('a failure here does not disturb the sessions list', () async {
      final getOverall = _MockGetOverall();
      when(() => getOverall(any())).thenAnswer(
        (_) async =>
            const Left<Failure, AttendanceOverview>(ServerFailure('boom')),
      );

      final overview = AttendanceOverviewCubit(getOverall: getOverall);
      addTearDown(overview.close);

      await overview.load();
      await cubit.load();

      expect(overview.state.status, RemoteStatus.failure);
      expect(cubit.state.status, RemoteStatus.success);
      expect(cubit.state.data!.items, isNotEmpty);
    });
  });

  group('AttendanceOverviewModel', () {
    // `overall` puts its tallies at the top level, unlike the per-course
    // endpoint which nests them under `statusCounts`.
    const json = {
      'overall': {
        'present': 41,
        'absent': 6,
        'late': 2,
        'leave': 1,
        'totalSessions': 50,
        'percentage': 82,
      },
      'courses': [
        {
          'courseId': 'c1',
          'courseName': 'Data Structures',
          'courseCode': 'CS201',
          'divisionId': 'd1',
          'present': 18,
          'absent': 2,
          'late': 0,
          'leave': 0,
          'totalSessions': 20,
          'percentage': 90,
        },
      ],
    };

    test('parses top-level counts and the course list', () {
      final overview = AttendanceOverviewModel.fromJson(json);

      expect(overview.overall.counts.present, 41);
      expect(overview.overall.counts.lateAndLeave, 3);
      expect(overview.overall.percentage, 82);

      final course = overview.courses.single;
      expect(course.courseCode, 'CS201');
      expect(course.divisionId, 'd1');
      expect(course.key, 'c1:d1');
      expect(course.hasSessions, isTrue);
    });

    test('an empty payload parses to zeroes rather than throwing', () {
      final overview = AttendanceOverviewModel.fromJson(const {});

      expect(overview.overall.totalSessions, 0);
      expect(overview.courses, isEmpty);
      expect(overview.isCourseListCapped, isFalse);
    });

    test('a course with no division reads as not yet held', () {
      final overview = AttendanceOverviewModel.fromJson(const {
        'courses': [
          {'courseId': 'c9', 'divisionId': '', 'totalSessions': 0, 'percentage': 0},
        ],
      });

      expect(overview.courses.single.hasSessions, isFalse);
      expect(overview.courses.single.key, 'c9:');
    });

    /// The server truncates the list at ten with no total to compare against,
    /// so "exactly ten" and "cut short" are the same observation.
    test('ten courses is treated as possibly capped', () {
      AttendanceOverview build(int count) => AttendanceOverviewModel.fromJson({
            'courses': [
              for (var i = 0; i < count; i++) {'courseId': 'c$i'},
            ],
          });

      expect(build(3).isCourseListCapped, isFalse);
      expect(build(10).isCourseListCapped, isTrue);
    });
  });

  group('AttendanceMeta.percentShade', () {
    test('switches at 75 and 50', () {
      expect(AttendanceMeta.percentShade(100), TwColors.emerald);
      expect(AttendanceMeta.percentShade(75), TwColors.emerald);
      expect(AttendanceMeta.percentShade(74), TwColors.amber);
      expect(AttendanceMeta.percentShade(50), TwColors.amber);
      expect(AttendanceMeta.percentShade(49), TwColors.rose);
      expect(AttendanceMeta.percentShade(0), TwColors.rose);
    });
  });

  group('Fmt.dmyLong', () {
    test('formats a bare date with a two-digit day', () {
      expect(Fmt.dmyLong('2026-08-02'), '02 Aug 2026');
    });

    /// Sliced, not parsed: a `Z`-suffixed value must not shift the date back a
    /// day for anyone west of UTC.
    test('does not shift a UTC-suffixed date', () {
      expect(Fmt.dmyLong('2026-08-02T00:00:00.000Z'), '02 Aug 2026');
    });

    test('degrades to an em dash on unusable input', () {
      expect(Fmt.dmyLong(null), '—');
      expect(Fmt.dmyLong('2026'), '—');
      expect(Fmt.dmyLong('2026-99-02'), '—');
    });
  });
}
