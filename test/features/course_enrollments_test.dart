import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:college_level/core/common/bloc/remote_cubit.dart';
import 'package:college_level/core/config/theme/app_colors.dart';
import 'package:college_level/core/constants/api_urls.dart';
import 'package:college_level/core/error/failures.dart';
import 'package:college_level/core/network/api_response.dart';
import 'package:college_level/features/teacher/enrollments/data/models/course_enrollment_model.dart';
import 'package:college_level/features/teacher/enrollments/domain/entities/course_enrollment.dart';
import 'package:college_level/features/teacher/enrollments/domain/usecases/enrollment_usecases.dart';
import 'package:college_level/features/teacher/enrollments/presentation/bloc/enrollments_cubit.dart';

class _MockEnrollments extends Mock implements EnrollmentUseCases {}

Map<String, dynamic> _row(
  String id, {
  String name = 'Ravi Kumar',
  String? roll = 'CS21-014',
  String status = 'active',
}) =>
    {
      'id': id,
      'studentId': 'sp-$id',
      'userId': 'u-$id',
      'status': status,
      'user': {'fullName': name, 'email': '$id@x.edu'},
      'student': {'rollNumber': roll, 'prnNumber': 'PRN$id'},
      'division': {'name': 'A', 'code': 'A'},
    };

void main() {
  group('CourseEnrollmentRowModel', () {
    test('reads identity, roll and division from their nested objects', () {
      final row = CourseEnrollmentRowModel.fromJson(_row('1'));

      expect(row.fullName, 'Ravi Kumar');
      expect(row.email, '1@x.edu');
      expect(row.rollNumber, 'CS21-014');
      expect(row.prnNumber, 'PRN1');
      expect(row.divisionName, 'A');
      expect(row.status, 'active');
    });

    test('falls back to the email when no name is set', () {
      final row = CourseEnrollmentRowModel.fromJson(const {
        'id': '1',
        'status': 'active',
        'user': {'email': 'nameless@x.edu'},
      });

      expect(row.fullName, 'nameless@x.edu');
    });

    test('absent nested objects degrade rather than throwing', () {
      final row = CourseEnrollmentRowModel.fromJson(const {
        'id': '1',
        'status': 'active',
      });

      expect(row.fullName, '');
      expect(row.rollNumber, isNull);
      expect(row.divisionName, isNull);
    });

    test('the unenrolled picker row is flat, not joined', () {
      final student = UnenrolledStudentModel.fromJson(const {
        'id': 'sp1',
        'userId': 'u1',
        'fullName': 'Asha Rao',
        'email': 'asha@x.edu',
        'rollNumber': 'CS21-001',
      });

      expect(student.id, 'sp1');
      expect(student.userId, 'u1');
      expect(student.subtitle, 'CS21-001 · asha@x.edu');
    });

    test('search matches name, email and roll number', () {
      final row = CourseEnrollmentRowModel.fromJson(_row('1'));

      expect(row.matches(''), isTrue);
      expect(row.matches('ravi'), isTrue);
      expect(row.matches('CS21'), isTrue);
      expect(row.matches('1@x.edu'), isTrue);
      expect(row.matches('nothing'), isFalse);
    });
  });

  group('EnrollmentStatus', () {
    test('labels and tints', () {
      expect(EnrollmentStatus.label('dropped'), 'Dropped');
      expect(EnrollmentStatus.shade('active'), TwColors.emerald);
      expect(EnrollmentStatus.shade('archived'), TwColors.slate);
      expect(EnrollmentStatus.shade('dropped'), TwColors.rose);
    });
  });

  group('EnrollmentsCubit', () {
    late _MockEnrollments enrollments;

    setUp(() => enrollments = _MockEnrollments());

    void stub(int count) {
      when(() => enrollments.list(any())).thenAnswer(
        (_) async => Right([
          for (var i = 0; i < count; i++)
            CourseEnrollmentRowModel.fromJson(
              _row('$i', name: 'Student $i', roll: 'R$i'),
            ),
        ]),
      );
    }

    test('pages client-side at ten', () async {
      // The endpoint is not paginated in practice — the web pulls 100 and
      // pages locally, so this does too.
      stub(25);
      final cubit = EnrollmentsCubit(enrollments: enrollments, courseId: 'c1');
      await cubit.load();

      expect(cubit.visible, hasLength(10));
      expect(cubit.totalPages, 3);

      cubit.setPage(3);
      expect(cubit.visible, hasLength(5));
      await cubit.close();
    });

    test('search narrows the list and resets to page one', () async {
      stub(25);
      final cubit = EnrollmentsCubit(enrollments: enrollments, courseId: 'c1');
      await cubit.load();
      cubit.setPage(3);

      cubit.setSearch('Student 1');
      // "Student 1", "Student 1x" — 1, 10..19.
      expect(cubit.matching.length, 11);
      expect(cubit.page, 1);
      await cubit.close();
    });

    test('a search that shortens the list cannot strand the reader', () async {
      stub(25);
      final cubit = EnrollmentsCubit(enrollments: enrollments, courseId: 'c1');
      await cubit.load();
      cubit.setPage(3);
      // Page is clamped, so the rows are the last page rather than empty.
      cubit.setSearch('Student 7');

      expect(cubit.visible, isNotEmpty);
      await cubit.close();
    });

    test('enrolling reports partial success rather than claiming all', () async {
      stub(0);
      var call = 0;
      when(() => enrollments.enroll(
            courseId: any(named: 'courseId'),
            studentId: any(named: 'studentId'),
            userId: any(named: 'userId'),
          )).thenAnswer((_) async {
        call++;
        // The web fires one request per student and swallows each failure, so
        // a bad row must not lose the rest of the batch.
        return call == 2
            ? const Left(ServerFailure('nope'))
            : const Right(null);
      });

      final cubit = EnrollmentsCubit(enrollments: enrollments, courseId: 'c1');
      final result = await cubit.enrollAll(const [
        UnenrolledStudent(id: 'a', userId: 'ua', fullName: 'A'),
        UnenrolledStudent(id: 'b', userId: 'ub', fullName: 'B'),
        UnenrolledStudent(id: 'c', userId: 'uc', fullName: 'C'),
      ]);

      expect(result.enrolled, 2);
      expect(result.failed, 1);
      await cubit.close();
    });

    test('a status change reloads the list', () async {
      stub(1);
      when(() => enrollments.setStatus(
            id: any(named: 'id'),
            status: any(named: 'status'),
          )).thenAnswer((_) async => const Right(null));

      final cubit = EnrollmentsCubit(enrollments: enrollments, courseId: 'c1');
      await cubit.load();
      final failure = await cubit.setStatus(id: 'e1', status: 'archived');

      expect(failure, isNull);
      verify(() => enrollments.list(any())).called(2);
      await cubit.close();
    });

    test('a failed mutation is returned and does not reload', () async {
      stub(1);
      when(() => enrollments.remove(any()))
          .thenAnswer((_) async => const Left(ForbiddenFailure('nope')));

      final cubit = EnrollmentsCubit(enrollments: enrollments, courseId: 'c1');
      await cubit.load();
      final failure = await cubit.remove('e1');

      expect(failure, isA<ForbiddenFailure>());
      verify(() => enrollments.list(any())).called(1);
      await cubit.close();
    });

    test('a failed load surfaces rather than showing an empty roster', () async {
      when(() => enrollments.list(any()))
          .thenAnswer((_) async => const Left(ForbiddenFailure('nope')));

      final cubit = EnrollmentsCubit(enrollments: enrollments, courseId: 'c1');
      await cubit.load();

      expect(cubit.state.status, RemoteStatus.failure);
      await cubit.close();
    });

    test('the picker drops an empty search rather than sending it', () async {
      when(() => enrollments.unenrolled(
            courseId: any(named: 'courseId'),
            search: any(named: 'search'),
            page: any(named: 'page'),
          )).thenAnswer(
        (_) async => Right(Paginated.emptyOf<UnenrolledStudent>()),
      );

      final cubit = EnrollmentsCubit(enrollments: enrollments, courseId: 'c1');
      await cubit.searchUnenrolled(search: '');

      verify(
        () => enrollments.unenrolled(
          courseId: 'c1',
          search: null,
          page: 1,
        ),
      ).called(1);
      await cubit.close();
    });
  });

  group('endpoints', () {
    test('the enrolment paths match the backend router', () {
      expect(ApiUrls.courseEnrollments, '/course-enrollments');
      expect(ApiUrls.courseEnrollment('e1'), '/course-enrollments/e1');
      expect(
        ApiUrls.courseEnrollmentStatus('e1'),
        '/course-enrollments/e1/status',
      );
      expect(
        ApiUrls.unenrolledStudents('c1'),
        '/courses/c1/unenrolled-students',
      );
    });
  });
}
