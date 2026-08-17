import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:college_level/core/error/failures.dart';
import 'package:college_level/core/network/api_response.dart';
import 'package:college_level/features/assessments/domain/entities/student_assessment.dart';
import 'package:college_level/features/assessments/domain/usecases/list_course_assessments_usecase.dart';
import 'package:college_level/features/assessments/presentation/bloc/assignments_cubit.dart';
import 'package:college_level/features/courses/domain/entities/course.dart';
import 'package:college_level/features/courses/domain/usecases/course_usecases.dart';

class _MockListAll extends Mock implements ListAllAssessmentsUseCase {}

class _MockListCourses extends Mock implements ListEnrolledCoursesUseCase {}

StudentAssessment _assignment(String id) => StudentAssessment(
      id: id,
      title: 'Assignment $id',
      category: 'course_assignment',
      type: 'questions',
      totalMarks: 20,
      resultsPublished: false,
    );

Paginated<StudentAssessment> _page({
  required int page,
  required int totalPages,
  int items = 2,
}) =>
    Paginated<StudentAssessment>(
      items: [for (var i = 0; i < items; i++) _assignment('$page-$i')],
      pagination: Pagination(
        page: page,
        limit: 20,
        total: totalPages * items,
        totalPages: totalPages,
      ),
    );

/// The Assignments screen is the same endpoint the Quizzes screen calls, and
/// the only thing separating them is a parameter this screen must **never**
/// send: with no `category` the backend excludes the quiz categories. Set one
/// by accident and this quietly becomes a second Quizzes screen — which looks
/// like wrong data, not like a bug in a query. That, and the
/// `??`-swallows-null trap in `copyWith`, are what these tests pin.
void main() {
  late _MockListAll listAll;
  late _MockListCourses listCourses;
  late AssignmentsCubit cubit;

  List<AssessmentQueryParams> capturedQueries() =>
      verify(() => listAll(captureAny())).captured.cast<AssessmentQueryParams>();

  setUpAll(() {
    registerFallbackValue(const AssessmentQueryParams());
    registerFallbackValue(const ListCoursesParams());
  });

  setUp(() {
    listAll = _MockListAll();
    listCourses = _MockListCourses();
    when(() => listAll(any())).thenAnswer(
      (_) async => Right<Failure, Paginated<StudentAssessment>>(
        _page(page: 1, totalPages: 1),
      ),
    );
    cubit = AssignmentsCubit(listAll: listAll, listCourses: listCourses);
  });

  tearDown(() => cubit.close());

  group('category', () {
    test('is never sent, on any request the screen makes', () async {
      await cubit.load();
      await cubit.setSearch('essay');
      await cubit.setFilters(courseId: 'course-1', status: 'submitted');

      // The inverse of the Quizzes screen's invariant. A category appearing
      // here would fill the Assignments list with quizzes.
      expect(
        capturedQueries().map((query) => query.category),
        everyElement(isNull),
      );
    });
  });

  group('filters', () {
    test('applies course and status in one request', () async {
      await cubit.setFilters(courseId: 'course-1', status: 'evaluated');

      // One capture pass: `verify` consumes the recorded calls, so counting
      // and inspecting them cannot be two separate verifications.
      final queries = capturedQueries();

      // Two setters in sequence would fire twice and paint a throwaway page.
      expect(queries, hasLength(1));
      expect(queries.single.courseId, 'course-1');
      expect(queries.single.status, 'evaluated');
    });

    test('null clears a filter rather than leaving it in place', () async {
      await cubit.setFilters(courseId: 'course-1', status: 'submitted');
      expect(cubit.query.courseId, 'course-1');

      // `copyWith(courseId: null)` alone keeps 'course-1' — the `??` fallback
      // swallows the null, so the clear flags have to carry it.
      await cubit.setFilters();

      expect(cubit.query.courseId, isNull);
      expect(cubit.query.status, isNull);
    });

    test('clears one filter while keeping the other', () async {
      await cubit.setFilters(courseId: 'course-1', status: 'submitted');
      await cubit.setFilters(status: 'submitted');

      expect(cubit.query.courseId, isNull);
      expect(cubit.query.status, 'submitted');
    });

    test('preserves the search term, which the sheet does not own', () async {
      await cubit.setSearch('graphs');
      await cubit.setFilters(status: 'in_progress');

      expect(capturedQueries().last.search, 'graphs');
    });

    test('every change restarts from page 1', () async {
      when(() => listAll(any())).thenAnswer(
        (_) async => Right<Failure, Paginated<StudentAssessment>>(
          _page(page: 1, totalPages: 3),
        ),
      );
      await cubit.load();
      await cubit.loadMore();
      await cubit.setFilters(status: 'evaluated');

      // A filter change invalidates pagination: page 2 of the old filter is a
      // slice of a differently-filtered set.
      expect(capturedQueries().last.page, 1);
    });

    test('hasFilters is false at defaults and true for each filter', () async {
      expect(cubit.query.hasFilters, isFalse);

      await cubit.setSearch('trees');
      expect(cubit.query.hasFilters, isTrue);

      await cubit.setSearch('');
      await cubit.setFilters(courseId: 'course-1');
      expect(cubit.query.hasFilters, isTrue);
      expect(cubit.query.activeFilterCount, 1);
    });
  });

  group('pagination', () {
    setUp(() {
      when(() => listAll(any())).thenAnswer((invocation) async {
        final query = invocation.positionalArguments.first
            as AssessmentQueryParams;
        return Right<Failure, Paginated<StudentAssessment>>(
          _page(page: query.page, totalPages: 2),
        );
      });
    });

    test('loadMore requests the next page and appends to what is shown',
        () async {
      await cubit.load();
      expect(cubit.state.data!.items, hasLength(2));

      await cubit.loadMore();

      expect(capturedQueries().last.page, 2);
      // Appended, not replaced — an infinite list that swaps pages loses
      // everything the user has already scrolled past.
      expect(cubit.state.data!.items, hasLength(4));
    });

    test('stops at the last page', () async {
      await cubit.load();
      await cubit.loadMore();
      expect(cubit.hasMore, isFalse);

      await cubit.loadMore();

      // Three would mean the footer keeps asking for a page that isn't there.
      verify(() => listAll(any())).called(2);
    });

    test('ignores a second loadMore while one is in flight', () async {
      await cubit.load();

      final blocked = Completer<Either<Failure, Paginated<StudentAssessment>>>();
      when(() => listAll(any())).thenAnswer((_) => blocked.future);

      final first = cubit.loadMore();
      final second = cubit.loadMore();
      blocked.complete(
        Right<Failure, Paginated<StudentAssessment>>(_page(page: 2, totalPages: 2)),
      );
      await Future.wait([first, second]);

      // One load + one loadMore. A scroll that fires twice must not double up.
      verify(() => listAll(any())).called(2);
    });

    test('a failed loadMore keeps the pages already on screen', () async {
      await cubit.load();
      when(() => listAll(any())).thenAnswer(
        (_) async => const Left<Failure, Paginated<StudentAssessment>>(
          NetworkFailure(),
        ),
      );

      await cubit.loadMore();

      expect(cubit.state.data!.items, hasLength(2));
      expect(cubit.state.failure, isNotNull);
    });
  });

  group('list item equality', () {
    /// The same row, varying only the field under test.
    StudentAssessment row({
      AssessmentCourseRef? course,
      String? endDate = '2026-03-01T10:00:00.000Z',
      bool resultsPublished = false,
    }) =>
        StudentAssessment(
          id: 'q1',
          title: 'Assignment',
          category: 'course_assignment',
          type: 'questions',
          totalMarks: 10,
          resultsPublished: resultsPublished,
          endDate: endDate,
          course: course,
        );

    test('rows differing only by course are not equal', () {
      // `props` has to carry the aggregate-only fields. Bloc drops an emission
      // equal to the current state, so if two rows differing only by course
      // compared equal, applying a course filter that returned same-shaped
      // rows would leave the old list on screen.
      expect(
        row(),
        isNot(
          row(
            course:
                const AssessmentCourseRef(id: 'c1', name: 'DS', code: 'CS201'),
          ),
        ),
      );
    });

    test('a moved due date or a published result is not equal', () {
      // Both change on their own: a teacher extends a deadline, or publishes
      // results, without anything else about the row moving.
      expect(row(), isNot(row(endDate: '2026-03-08T10:00:00.000Z')));
      expect(row(), isNot(row(resultsPublished: true)));
    });
  });

  group('course options', () {
    test('are fetched once and cached for the filter sheet', () async {
      when(() => listCourses(any())).thenAnswer(
        (_) async => Right<Failure, Paginated<CourseEnrollment>>(
          Paginated<CourseEnrollment>(
            items: const [
              CourseEnrollment(
                id: 'e1',
                status: 'active',
                course: Course(
                  id: 'course-1',
                  name: 'Data Structures',
                  code: 'CS201',
                  type: 'regular',
                  status: 'active',
                  credits: 4,
                  colorCode: '#3B82F6',
                ),
              ),
            ],
            pagination: Pagination.empty,
          ),
        ),
      );

      final first = await cubit.courseOptions();
      final second = await cubit.courseOptions();

      expect(first.single.code, 'CS201');
      expect(second, first);
      // Opening the sheet twice must not re-fetch the student's whole course
      // list; it does not change while the screen is open.
      verify(() => listCourses(any())).called(1);
    });

    test('fall back to the courses already on screen when the fetch fails',
        () async {
      when(() => listAll(any())).thenAnswer(
        (_) async => Right<Failure, Paginated<StudentAssessment>>(
          Paginated<StudentAssessment>(
            items: [
              StudentAssessment(
                id: 'q1',
                title: 'Assignment',
                category: 'course_assignment',
                type: 'questions',
                totalMarks: 10,
                resultsPublished: false,
                course: const AssessmentCourseRef(
                  id: 'course-9',
                  name: 'Algorithms',
                  code: 'CS301',
                ),
              ),
            ],
            pagination: Pagination.empty,
          ),
        ),
      );
      when(() => listCourses(any())).thenAnswer(
        (_) async =>
            const Left<Failure, Paginated<CourseEnrollment>>(NetworkFailure()),
      );

      await cubit.load();
      final options = await cubit.courseOptions();

      // A partial list beats an empty filter: the student can still narrow to
      // the courses they can see.
      expect(options.single.id, 'course-9');
    });
  });
}
