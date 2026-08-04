import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/course.dart';
import '../entities/course_tree.dart';
import '../repositories/course_repository.dart';

/// The student's enrolled courses.
class ListEnrolledCoursesUseCase
    implements UseCase<Paginated<CourseEnrollment>, ListCoursesParams> {
  const ListEnrolledCoursesUseCase(this._repository);

  final CourseRepository _repository;

  @override
  Future<Either<Failure, Paginated<CourseEnrollment>>> call(
    ListCoursesParams params,
  ) =>
      _repository.listEnrolledCourses(
        page: params.page,
        limit: params.limit,
        semesterId: params.semesterId,
        status: params.status,
        search: params.search,
      );
}

class ListCoursesParams extends Equatable {
  const ListCoursesParams({
    this.page = 1,
    this.limit = 100,
    this.semesterId,
    this.status,
    this.search,
  });

  final int page;
  final int limit;
  final String? semesterId;
  final String? status;
  final String? search;

  @override
  List<Object?> get props => [page, limit, semesterId, status, search];
}

class GetCourseUseCase implements UseCase<Course, IdParams> {
  const GetCourseUseCase(this._repository);

  final CourseRepository _repository;

  @override
  Future<Either<Failure, Course>> call(IdParams params) =>
      _repository.getCourse(params.id);
}

class GetCourseTreeUseCase implements UseCase<CourseTree, IdParams> {
  const GetCourseTreeUseCase(this._repository);

  final CourseRepository _repository;

  @override
  Future<Either<Failure, CourseTree>> call(IdParams params) =>
      _repository.getCourseTree(params.id);
}

/// Marks a material complete or clears the completion.
class SetMaterialCompletedUseCase
    implements UseCase<Unit, SetMaterialCompletedParams> {
  const SetMaterialCompletedUseCase(this._repository);

  final CourseRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(SetMaterialCompletedParams params) =>
      _repository.setMaterialCompleted(
        materialId: params.materialId,
        completed: params.completed,
      );
}

class SetMaterialCompletedParams extends Equatable {
  const SetMaterialCompletedParams({
    required this.materialId,
    required this.completed,
  });

  final String materialId;
  final bool completed;

  @override
  List<Object?> get props => [materialId, completed];
}
