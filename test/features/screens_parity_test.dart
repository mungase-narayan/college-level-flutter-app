import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:college_level/core/error/failures.dart';
import 'package:college_level/core/network/api_response.dart';
import 'package:college_level/features/assessments/domain/entities/student_assessment.dart';
import 'package:college_level/features/assessments/domain/usecases/list_course_assessments_usecase.dart';
import 'package:college_level/features/assessments/presentation/bloc/assignments_cubit.dart';
import 'package:college_level/features/assessments/presentation/bloc/quizzes_cubit.dart';
import 'package:college_level/features/assessments/presentation/pages/assignments_page.dart';
import 'package:college_level/features/assessments/presentation/pages/quizzes_page.dart';
import 'package:college_level/features/courses/domain/entities/course.dart';
import 'package:college_level/features/courses/domain/usecases/course_usecases.dart';
import 'package:college_level/features/courses/presentation/bloc/courses_cubit.dart';
import 'package:college_level/features/courses/presentation/pages/courses_page.dart';

import '../support/platform_parity.dart';

class _MockListAll extends Mock implements ListAllAssessmentsUseCase {}

class _MockListCourses extends Mock implements ListEnrolledCoursesUseCase {}

/// Every sidebar destination that owns a real screen, pumped down both the
/// Material and the Liquid Glass branch.
///
/// These assert *features*, not pixels — the two branches are meant to look
/// different. What must not differ is which controls exist and what they say.
void main() {
  late _MockListAll listAll;
  late _MockListCourses listCourses;

  setUpAll(() {
    registerFallbackValue(const AssessmentQueryParams());
    registerFallbackValue(const ListCoursesParams());
  });

  setUp(() {
    listAll = _MockListAll();
    listCourses = _MockListCourses();

    when(() => listAll(any())).thenAnswer(
      (_) async => Right<Failure, Paginated<StudentAssessment>>(
        Paginated.emptyOf<StudentAssessment>(),
      ),
    );
    when(() => listCourses(any())).thenAnswer(
      (_) async => Right<Failure, Paginated<CourseEnrollment>>(
        Paginated.emptyOf<CourseEnrollment>(),
      ),
    );
  });

  group('Quizzes', () {
    bothPlatforms('renders search, the filter button and the empty state',
        (tester, host) async {
      await tester.pumpWidget(
        host(
          BlocProvider(
            create: (_) =>
                QuizzesCubit(listAll: listAll, listCourses: listCourses),
            child: const QuizzesPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Search quizzes'), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
      expect(find.text('No quizzes yet'), findsOneWidget);
    });

    bothPlatforms('the filter sheet carries Status, Reset and Apply',
        (tester, host) async {
      await tester.pumpWidget(
        host(
          BlocProvider(
            create: (_) =>
                QuizzesCubit(listAll: listAll, listCourses: listCourses),
            child: const QuizzesPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Status'), findsOneWidget);
      expect(find.text('All statuses'), findsOneWidget);
      expect(find.text('Submitted'), findsOneWidget);
      // The arrangement this session standardised on, everywhere.
      expect(find.text('Reset'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
    });
  });

  group('Assignments', () {
    bothPlatforms('renders search, the filter button and the empty state',
        (tester, host) async {
      await tester.pumpWidget(
        host(
          BlocProvider(
            create: (_) =>
                AssignmentsCubit(listAll: listAll, listCourses: listCourses),
            child: const AssignmentsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
      expect(find.textContaining('assignment'), findsWidgets);
    });

    bothPlatforms('the filter sheet carries Status, Reset and Apply',
        (tester, host) async {
      await tester.pumpWidget(
        host(
          BlocProvider(
            create: (_) =>
                AssignmentsCubit(listAll: listAll, listCourses: listCourses),
            child: const AssignmentsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
    });
  });

  group('Courses', () {
    bothPlatforms('renders its empty state', (tester, host) async {
      await tester.pumpWidget(
        host(
          BlocProvider(
            create: (_) => CoursesCubit(listCourses),
            child: const CoursesPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Whatever the copy, the screen must resolve to a state rather than
      // sitting on a skeleton forever.
      expect(find.byType(CoursesPage), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
