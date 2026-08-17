import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/student_assessment.dart';
import '../repositories/assessment_repository.dart';

/// Backs both the Assignments and the Quiz tab; only [CourseAssessmentParams
/// .category] differs.
class ListCourseAssessmentsUseCase
    implements UseCase<List<StudentAssessment>, CourseAssessmentParams> {
  const ListCourseAssessmentsUseCase(this._repository);

  final AssessmentRepository _repository;

  @override
  Future<Either<Failure, List<StudentAssessment>>> call(
    CourseAssessmentParams params,
  ) =>
      _repository.listForCourse(
        courseId: params.courseId,
        category: params.category,
        courseMaterialId: params.courseMaterialId,
      );
}

class CourseAssessmentParams extends Equatable {
  const CourseAssessmentParams({
    required this.courseId,
    this.category,
    this.courseMaterialId,
  });

  /// Assignments: leave null (the backend then excludes quiz categories).
  const CourseAssessmentParams.assignments(String courseId)
      : this(courseId: courseId);

  /// Quizzes: the backend filters to the quiz categories.
  const CourseAssessmentParams.quizzes(String courseId)
      : this(courseId: courseId, category: 'quiz');

  final String courseId;
  final String? category;
  final String? courseMaterialId;

  @override
  List<Object?> get props => [courseId, category, courseMaterialId];
}

/// Every quiz (or assignment) across the student's enrolled courses — the
/// standalone Quizzes screen, as opposed to a single course's tab.
class ListAllAssessmentsUseCase
    implements UseCase<Paginated<StudentAssessment>, AssessmentQueryParams> {
  const ListAllAssessmentsUseCase(this._repository);

  final AssessmentRepository _repository;

  @override
  Future<Either<Failure, Paginated<StudentAssessment>>> call(
    AssessmentQueryParams params,
  ) =>
      _repository.listAll(
        category: params.category,
        courseId: params.courseId,
        status: params.status,
        search: params.search,
        page: params.page,
        limit: params.limit,
      );
}

/// The query behind the standalone list: what to fetch, filtered how, and which
/// page of it.
class AssessmentQueryParams extends Equatable {
  const AssessmentQueryParams({
    this.category,
    this.courseId,
    this.status,
    this.search,
    this.page = 1,
    this.limit = 20,
  });

  /// Load-bearing: with no category the backend *excludes* quizzes and returns
  /// assignments, so the Quizzes screen must always carry `'quiz'`.
  final String? category;

  final String? courseId;

  /// `not_started | in_progress | submitted | evaluated`.
  final String? status;

  /// Matched against the title, server-side.
  final String? search;

  final int page;
  final int limit;

  /// Whether any user-set filter is applied — drives the badge on the filter
  /// button and the "no results" copy. [category] is not a user filter; it is
  /// what the screen *is*.
  bool get hasFilters =>
      (search ?? '').isNotEmpty || courseId != null || status != null;

  int get activeFilterCount =>
      (courseId != null ? 1 : 0) + (status != null ? 1 : 0);

  /// `clearX` is what lets a filter be *removed*: a bare `courseId: null` is
  /// indistinguishable from "leave unchanged" once `??` has swallowed it.
  AssessmentQueryParams copyWith({
    String? category,
    String? courseId,
    String? status,
    String? search,
    int? page,
    int? limit,
    bool clearCourse = false,
    bool clearStatus = false,
  }) =>
      AssessmentQueryParams(
        category: category ?? this.category,
        courseId: clearCourse ? null : (courseId ?? this.courseId),
        status: clearStatus ? null : (status ?? this.status),
        search: search ?? this.search,
        page: page ?? this.page,
        limit: limit ?? this.limit,
      );

  @override
  List<Object?> get props => [category, courseId, status, search, page, limit];
}
