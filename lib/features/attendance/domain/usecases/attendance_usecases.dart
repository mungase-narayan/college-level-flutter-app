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

class GetOverallAttendanceUseCase
    implements UseCase<AttendanceOverview, NoParams> {
  const GetOverallAttendanceUseCase(this._repository);

  final AttendanceRepository _repository;

  @override
  Future<Either<Failure, AttendanceOverview>> call(NoParams params) =>
      _repository.getOverallAnalytics();
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

  /// The `clear*` flags exist because `??` cannot express "set this to null":
  /// passing `courseId: null` to drop the filter would silently keep the old
  /// value. Every nullable field therefore needs its own flag.
  AttendanceSessionParams copyWith({
    int? page,
    String? courseId,
    String? status,
    bool clearCourseId = false,
    bool clearStatus = false,
  }) =>
      AttendanceSessionParams(
        courseId: clearCourseId ? null : (courseId ?? this.courseId),
        status: clearStatus ? null : (status ?? this.status),
        page: page ?? this.page,
        limit: limit,
      );

  /// Whether the list is narrowed by anything the user chose — drives the
  /// filter button's badge and picks the "no matches" empty copy over the
  /// "nothing recorded yet" one.
  bool get hasFilters => activeFilterCount > 0;

  int get activeFilterCount =>
      (courseId != null ? 1 : 0) + (status != null ? 1 : 0);

  @override
  List<Object?> get props => [courseId, status, page, limit];
}
