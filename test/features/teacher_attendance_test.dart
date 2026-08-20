import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:college_level/core/common/bloc/remote_cubit.dart';
import 'package:college_level/core/constants/api_urls.dart';
import 'package:college_level/core/config/theme/app_colors.dart';
import 'package:college_level/core/error/failures.dart';
import 'package:college_level/features/teacher/attendance/data/models/attendance_model.dart';
import 'package:college_level/features/teacher/attendance/domain/entities/attendance_session.dart';
import 'package:college_level/features/teacher/attendance/domain/usecases/attendance_usecases.dart';
import 'package:college_level/features/teacher/attendance/presentation/bloc/attendance_tab_cubit.dart';
import 'package:college_level/features/teacher/attendance/presentation/bloc/roster_cubit.dart';

class _MockAttendance extends Mock implements AttendanceUseCases {}

AttendanceSessionDetail _detail({
  required List<Map<String, dynamic>> records,
  String status = AttendanceStatus.draft,
}) =>
    AttendanceSessionDetailModel.fromJson({
      'id': 's1',
      'courseId': 'c1',
      'divisionId': 'd1',
      'type': 'lecture',
      'status': status,
      'sessionDate': '2026-08-19',
      'records': records,
    });

Map<String, dynamic> _student(String id, {String? status}) => {
      'studentId': id,
      'fullName': 'Student $id',
      'isMarked': status != null,
      'status': status,
    };

void main() {
  group('AttendanceSessionModel', () {
    test('parses a list row', () {
      final row = AttendanceSessionModel.fromJson(const {
        'id': 's1',
        'courseId': 'c1',
        'divisionId': 'd1',
        'type': 'lab',
        'status': 'finalized',
        'sessionDate': '2026-08-19',
        'topic': 'AVL rotations',
        'rosterSize': 60,
        'markedCount': 58,
        'presentCount': 55,
      });

      expect(row.type, 'lab');
      expect(row.title, 'AVL rotations');
      expect(row.isDraft, isFalse);
      // Only a draft can be edited or deleted; the API 409s otherwise.
      expect(row.isEditable, isFalse);
      expect(row.markedCount, 58);
    });

    test('falls back to the type when no topic was given', () {
      final row = AttendanceSessionModel.fromJson(const {
        'id': 's1',
        'type': 'tutorial',
        'status': 'draft',
        'sessionDate': '2026-08-19',
      });

      expect(row.title, 'Tutorial');
      expect(row.isEditable, isTrue);
    });

    test('the detail payload carries the session and its roster together', () {
      final detail = _detail(
        records: [_student('a', status: 'absent'), _student('b')],
      );

      expect(detail.session.id, 's1');
      expect(detail.records, hasLength(2));
      expect(detail.records.first.status, 'absent');
      expect(detail.records.last.isMarked, isFalse);
    });

    test('analytics reads the nested status counts', () {
      final analytics = AttendanceAnalyticsModel.fromJson(const {
        'totalSessions': 24,
        'statusCounts': {'present': 60, 'absent': 20, 'late': 15, 'leave': 5},
      });

      expect(analytics.totalSessions, 24);
      expect(analytics.marked, 100);
      expect(analytics.presentPercent, 60);
    });

    test('an unmarked rollup reports no percentage rather than zero', () {
      // 0% would read as everyone absent; null reads as no data.
      final analytics = AttendanceAnalyticsModel.fromJson(const {
        'totalSessions': 3,
        'statusCounts': {'present': 0, 'absent': 0, 'late': 0, 'leave': 0},
      });

      expect(analytics.presentPercent, isNull);
    });

    test('a slot with a session is no longer pending', () {
      final pending = TodaySlotModel.fromJson(const {
        'id': 'ts1',
        'title': 'DS',
        'courseId': 'c1',
        'divisionId': 'd1',
      });
      final done = TodaySlotModel.fromJson(const {
        'id': 'ts2',
        'title': 'DS',
        'courseId': 'c1',
        'divisionId': 'd1',
        'sessionId': 's9',
      });

      expect(pending.isPending, isTrue);
      expect(done.isPending, isFalse);
    });
  });

  group('status tables', () {
    test('marks carry the web colours', () {
      expect(MarkStatus.shade(MarkStatus.present), TwColors.emerald);
      expect(MarkStatus.shade(MarkStatus.absent), TwColors.rose);
      expect(MarkStatus.shade(MarkStatus.late), TwColors.amber);
      expect(MarkStatus.shade(MarkStatus.leave), TwColors.cyan);
    });

    test('the segmented control order is present, absent, late, leave', () {
      expect(MarkStatus.options, ['present', 'absent', 'late', 'leave']);
    });

    test('session status labels and tints', () {
      expect(AttendanceStatus.label('draft'), 'Draft');
      expect(AttendanceStatus.shade('finalized'), TwColors.emerald);
    });
  });

  group('RosterCubit', () {
    late _MockAttendance attendance;

    setUp(() => attendance = _MockAttendance());

    void stub(AttendanceSessionDetail detail) {
      when(() => attendance.getSession(any()))
          .thenAnswer((_) async => Right(detail));
    }

    /// The behaviour the whole screen is built around: a teacher opens it,
    /// flips the few absentees, and saves. Seeding unmarked students to
    /// `present` is what makes that one gesture instead of forty.
    test('unmarked students seed to present', () async {
      stub(_detail(records: [_student('a'), _student('b', status: 'absent')]));

      final cubit = RosterCubit(attendance: attendance, sessionId: 's1');
      await cubit.load();

      expect(cubit.state.data!.marks['a'], MarkStatus.present);
      expect(cubit.state.data!.marks['b'], MarkStatus.absent);
      await cubit.close();
    });

    test('toggling a mark emits a new state', () async {
      // Regression: marks used to live outside the state, so re-emitting an
      // equal RemoteState was dropped by bloc and the toggle never repainted.
      stub(_detail(records: [_student('a')]));

      final cubit = RosterCubit(attendance: attendance, sessionId: 's1');
      await cubit.load();
      final before = cubit.state;

      cubit.setMark('a', MarkStatus.late);

      expect(cubit.state, isNot(before));
      expect(cubit.state.data!.marks['a'], MarkStatus.late);
      expect(cubit.state.data!.countOf(MarkStatus.late), 1);
      await cubit.close();
    });

    test('mark all present covers the whole roster, not one page', () async {
      stub(
        _detail(
          records: [
            for (var i = 0; i < 25; i++) _student('s$i', status: 'absent'),
          ],
        ),
      );

      final cubit = RosterCubit(attendance: attendance, sessionId: 's1');
      await cubit.load();
      cubit.markAllPresent();

      expect(cubit.state.data!.countOf(MarkStatus.present), 25);
      await cubit.close();
    });

    test('save posts every student, not a delta', () async {
      stub(_detail(records: [_student('a'), _student('b', status: 'absent')]));
      when(() => attendance.mark(
            sessionId: any(named: 'sessionId'),
            records: any(named: 'records'),
          )).thenAnswer((_) async => const Right(null));

      final cubit = RosterCubit(attendance: attendance, sessionId: 's1');
      await cubit.load();
      await cubit.save();

      final captured = verify(
        () => attendance.mark(
          sessionId: 's1',
          records: captureAny(named: 'records'),
        ),
      ).captured.single as List<({String status, String studentId})>;

      expect(captured, hasLength(2));
      expect(captured.map((r) => r.studentId), containsAll(['a', 'b']));
      await cubit.close();
    });

    /// The backend rejects `mark` once a session is finalized, so finalizing
    /// first would silently discard whatever the teacher had just toggled.
    test('finalize saves first, then finalizes', () async {
      stub(_detail(records: [_student('a')]));
      final calls = <String>[];

      when(() => attendance.mark(
            sessionId: any(named: 'sessionId'),
            records: any(named: 'records'),
          )).thenAnswer((_) async {
        calls.add('mark');
        return const Right(null);
      });
      when(() => attendance.finalize(any())).thenAnswer((_) async {
        calls.add('finalize');
        return const Right(null);
      });

      final cubit = RosterCubit(attendance: attendance, sessionId: 's1');
      await cubit.load();
      await cubit.saveAndFinalize();

      expect(calls, ['mark', 'finalize']);
      await cubit.close();
    });

    test('a failed save aborts before finalizing', () async {
      stub(_detail(records: [_student('a')]));
      when(() => attendance.mark(
            sessionId: any(named: 'sessionId'),
            records: any(named: 'records'),
          )).thenAnswer((_) async => const Left(ServerFailure('nope')));

      final cubit = RosterCubit(attendance: attendance, sessionId: 's1');
      await cubit.load();
      final failure = await cubit.saveAndFinalize();

      expect(failure, isA<ServerFailure>());
      verifyNever(() => attendance.finalize(any()));
      await cubit.close();
    });

    test('a finalized session is read-only and ignores marks', () async {
      stub(
        _detail(
          records: [_student('a', status: 'absent')],
          status: AttendanceStatus.finalized,
        ),
      );

      final cubit = RosterCubit(attendance: attendance, sessionId: 's1');
      await cubit.load();
      cubit.setMark('a', MarkStatus.present);
      cubit.markAllPresent();

      expect(cubit.state.data!.isReadOnly, isTrue);
      expect(cubit.state.data!.marks['a'], MarkStatus.absent);
      await cubit.close();
    });
  });

  group('AttendanceTabCubit', () {
    late _MockAttendance attendance;

    setUp(() {
      attendance = _MockAttendance();
      when(() => attendance.analytics(
            courseId: any(named: 'courseId'),
            divisionId: any(named: 'divisionId'),
          )).thenAnswer(
        (_) async => const Right(
          AttendanceAnalyticsModel(
            totalSessions: 1,
            present: 1,
            absent: 0,
            late: 0,
            leave: 0,
          ),
        ),
      );
      when(() => attendance.listSessions(
            courseId: any(named: 'courseId'),
            divisionId: any(named: 'divisionId'),
            status: any(named: 'status'),
            page: any(named: 'page'),
            limit: any(named: 'limit'),
          )).thenAnswer(
        (_) async => Right(AttendanceSessionPageModel.fromJson(const {'data': []})),
      );
      when(() => attendance.todaySlots(
            courseId: any(named: 'courseId'),
            divisionId: any(named: 'divisionId'),
          )).thenAnswer(
        (_) async => Right([
          TodaySlotModel.fromJson(const {
            'id': 'ts1',
            'title': 'DS',
            'courseId': 'c1',
            'divisionId': 'd1',
          }),
          TodaySlotModel.fromJson(const {
            'id': 'ts2',
            'title': 'DS',
            'courseId': 'c1',
            'divisionId': 'd1',
            'sessionId': 's9',
          }),
        ]),
      );
    });

    AttendanceTabCubit build() => AttendanceTabCubit(
          attendance: attendance,
          courseId: 'c1',
          divisionId: 'd1',
        );

    test('keeps only slots without a session yet', () async {
      final cubit = build();
      await cubit.load();

      expect(cubit.state.data!.pendingSlots, hasLength(1));
      expect(cubit.state.data!.pendingSlots.single.id, 'ts1');
      await cubit.close();
    });

    test('pending slots are dropped once filtered or paged', () async {
      // A slot is not a session, so it has no place in a filtered view.
      final cubit = build();
      await cubit.setStatus(AttendanceStatus.draft);

      expect(cubit.state.data!.pendingSlots, isEmpty);
      verifyNever(() => attendance.todaySlots(
            courseId: any(named: 'courseId'),
            divisionId: any(named: 'divisionId'),
          ));
      await cubit.close();
    });

    test('a failed rollup still shows the sessions list', () async {
      when(() => attendance.analytics(
            courseId: any(named: 'courseId'),
            divisionId: any(named: 'divisionId'),
          )).thenAnswer((_) async => const Left(ServerFailure('boom')));

      final cubit = build();
      await cubit.load();

      expect(cubit.state.status, RemoteStatus.success);
      expect(cubit.state.data!.analytics, isNull);
      await cubit.close();
    });

    test('a failed sessions read fails the tab', () async {
      when(() => attendance.listSessions(
            courseId: any(named: 'courseId'),
            divisionId: any(named: 'divisionId'),
            status: any(named: 'status'),
            page: any(named: 'page'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => const Left(NetworkFailure()));

      final cubit = build();
      await cubit.load();

      expect(cubit.state.status, RemoteStatus.failure);
      await cubit.close();
    });

    test('changing the status filter restarts at page one', () async {
      final cubit = build();
      await cubit.load();
      await cubit.setPage(3);
      await cubit.setStatus(AttendanceStatus.finalized);

      expect(cubit.page, 1);
      await cubit.close();
    });
  });

  group('endpoints', () {
    test('the attendance paths match the backend router', () {
      expect(ApiUrls.teacherAttendanceSessions, '/teacher/attendance/sessions');
      expect(
        ApiUrls.teacherAttendanceSession('s1'),
        '/teacher/attendance/sessions/s1',
      );
      expect(
        ApiUrls.teacherAttendanceMark('s1'),
        '/teacher/attendance/sessions/s1/mark',
      );
      expect(
        ApiUrls.teacherAttendanceFinalize('s1'),
        '/teacher/attendance/sessions/s1/finalize',
      );
      expect(ApiUrls.teacherAttendanceToday, '/teacher/attendance/today');
      expect(
        ApiUrls.teacherAttendanceAnalytics,
        '/teacher/attendance/analytics',
      );
    });
  });
}
