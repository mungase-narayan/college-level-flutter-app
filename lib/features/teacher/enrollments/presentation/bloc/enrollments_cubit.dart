import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../../../../core/error/failures.dart';
import '../../../../../core/network/api_response.dart';
import '../../domain/entities/course_enrollment.dart';
import '../../domain/usecases/enrollment_usecases.dart';

/// The enrolments tab.
///
/// The endpoint is not paginated in practice — the web pulls 100 rows and
/// searches and pages over them locally, so this does the same rather than
/// round-tripping for a substring match.
class EnrollmentsCubit extends Cubit<RemoteState<List<CourseEnrollmentRow>>> {
  EnrollmentsCubit({
    required EnrollmentUseCases enrollments,
    required this.courseId,
  })  : _enrollments = enrollments,
        super(const RemoteState());

  final EnrollmentUseCases _enrollments;
  final String courseId;

  static const pageSize = 10;

  List<CourseEnrollmentRow> _all = const [];
  String _search = '';
  int _page = 1;

  String get search => _search;
  int get page => _page;

  /// Everything matching the search, across all pages.
  List<CourseEnrollmentRow> get matching =>
      [for (final row in _all) if (row.matches(_search)) row];

  int get totalPages => (matching.length / pageSize).ceil().clamp(1, 9999);

  /// The rows for the current page, clamped so a search that shortens the list
  /// cannot strand the reader past the end of it.
  List<CourseEnrollmentRow> get visible {
    final rows = matching;
    final start = (_page.clamp(1, totalPages) - 1) * pageSize;
    return rows.skip(start).take(pageSize).toList(growable: false);
  }

  Future<void> load({bool refresh = false}) async {
    if (isClosed) return;
    emit(state.copyWith(
      status: RemoteStatus.loading,
      isRefreshing: refresh,
      clearFailure: true,
    ));

    final result = await _enrollments.list(courseId);
    if (isClosed) return;

    result.fold(
      (failure) => emit(state.copyWith(
        status: RemoteStatus.failure,
        failure: failure,
        isRefreshing: false,
      )),
      (rows) {
        _all = rows;
        emit(RemoteState(status: RemoteStatus.success, data: rows));
      },
    );
  }

  void setSearch(String value) {
    _search = value.trim();
    // A new search always restarts at page 1.
    _page = 1;
    if (!isClosed && state.isSuccess) emit(state.copyWith(data: _all));
  }

  void setPage(int value) {
    _page = value;
    if (!isClosed && state.isSuccess) emit(state.copyWith(data: _all));
  }

  /// Searches students not yet on the course, for the enrol picker.
  Future<Either<Failure, Paginated<UnenrolledStudent>>> searchUnenrolled({
    String? search,
    int page = 1,
  }) =>
      _enrollments.unenrolled(
        courseId: courseId,
        search: (search ?? '').isEmpty ? null : search,
        page: page,
      );

  Future<Failure?> setStatus({required String id, required String status}) =>
      _mutate(() => _enrollments.setStatus(id: id, status: status));

  Future<Failure?> remove(String id) => _mutate(() => _enrollments.remove(id));

  /// Enrols several students, one request each.
  ///
  /// The API has a `/bulk` endpoint but the web deliberately does not use it,
  /// so this matches: failures are counted per student rather than losing the
  /// whole batch to one bad row.
  Future<({int enrolled, int failed})> enrollAll(
    List<UnenrolledStudent> students,
  ) async {
    var enrolled = 0;
    var failed = 0;

    for (final student in students) {
      final result = await _enrollments.enroll(
        courseId: courseId,
        studentId: student.id,
        userId: student.userId,
      );
      result.fold((_) => failed++, (_) => enrolled++);
    }
    if (!isClosed && enrolled > 0) await load(refresh: true);
    return (enrolled: enrolled, failed: failed);
  }

  Future<Failure?> _mutate(Future<Either<Failure, void>> Function() action) async {
    final result = await action();
    if (isClosed) return null;

    final failure = result.fold<Failure?>((f) => f, (_) => null);
    if (failure == null) await load(refresh: true);
    return failure;
  }
}
