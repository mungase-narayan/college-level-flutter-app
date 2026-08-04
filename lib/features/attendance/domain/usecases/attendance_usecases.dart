import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/attendance.dart';
import '../repositories/attendance_repository.dart';

class GetCourseAttendanceUseCase implements UseCase<CourseAttendance, IdParams> {
  const GetCourseAttendanceUseCase(this._repository);

  final AttendanceRepository _repository;

  @override
  Future<Either<Failure, CourseAttendance>> call(IdParams params) =>
      _repository.getCourseAnalytics(params.id);
}

class ListAttendanceSessionsUseCase
    implements UseCase<Paginated<AttendanceSession>, AttendanceSessionParams> {
  const ListAttendanceSessionsUseCase(this._repository);

  final AttendanceRepository _repository;

  @override
  Future<Either<Failure, Paginated<AttendanceSession>>> call(
    AttendanceSessionParams params,
  ) =>
      _repository.listSessions(
        courseId: params.courseId,
        status: params.status,
        page: params.page,
        limit: params.limit,
      );
}

class AttendanceSessionParams extends Equatable {
  const AttendanceSessionParams({
    this.courseId,
    this.status,
    this.page = 1,
    this.limit = AttendanceMeta.pageSize,
  });

  final String? courseId;
  final String? status;
  final int page;
  final int limit;

  AttendanceSessionParams copyWith({
    int? page,
    String? status,
    bool clearStatus = false,
  }) =>
      AttendanceSessionParams(
        courseId: courseId,
        status: clearStatus ? null : (status ?? this.status),
        page: page ?? this.page,
        limit: limit,
      );

  @override
  List<Object?> get props => [courseId, status, page, limit];
}
