import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
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
