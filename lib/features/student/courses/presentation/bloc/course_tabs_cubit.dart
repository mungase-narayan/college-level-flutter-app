import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../../../../core/network/api_response.dart';
import '../../../../../core/usecases/usecase.dart';
import '../../../assessments/domain/entities/student_assessment.dart';
import '../../../assessments/domain/usecases/list_course_assessments_usecase.dart';
import '../../../attendance/domain/entities/attendance.dart';
import '../../../attendance/domain/usecases/attendance_usecases.dart';

/// Backs both the Assignments and the Quiz tab — only the category differs.
class CourseAssessmentsCubit extends Cubit<RemoteState<List<StudentAssessment>>> {
  CourseAssessmentsCubit({
    required ListCourseAssessmentsUseCase listAssessments,
    required this.courseId,
    required this.category,
    this.courseMaterialId,
  })  : _listAssessments = listAssessments,
        super(const RemoteState());

  final ListCourseAssessmentsUseCase _listAssessments;
  final String courseId;

  /// `null` for assignments (the backend then excludes quizzes), `'quiz'` for
  /// the Quiz tab.
  final String? category;

  /// Set by the material page's Assignments tab to narrow the list to the
  /// assignments published against that one material.
  final String? courseMaterialId;

  Future<void> load({bool refresh = false}) async {
    if (isClosed) return;
    emit(state.copyWith(
      status: RemoteStatus.loading,
      isRefreshing: refresh,
      clearFailure: true,
    ));

    final result = await _listAssessments(
      CourseAssessmentParams(
        courseId: courseId,
        category: category,
        courseMaterialId: courseMaterialId,
      ),
    );
    if (isClosed) return;

    result.fold(
      (failure) => emit(state.copyWith(
        status: RemoteStatus.failure,
        failure: failure,
        isRefreshing: false,
      )),
      (items) => emit(RemoteState(status: RemoteStatus.success, data: items)),
    );
  }
}

/// The per-course attendance tab: analytics tiles plus a paged session list.
class CourseAttendanceData extends Equatable {
  const CourseAttendanceData({required this.analytics, required this.sessions});

  final CourseAttendance analytics;
  final Paginated<AttendanceSession> sessions;

  @override
  List<Object?> get props => [analytics, sessions];
}

class CourseAttendanceCubit extends Cubit<RemoteState<CourseAttendanceData>> {
  CourseAttendanceCubit({
    required GetCourseAttendanceUseCase getAnalytics,
    required ListAttendanceSessionsUseCase listSessions,
    required this.courseId,
  })  : _getAnalytics = getAnalytics,
        _listSessions = listSessions,
        super(const RemoteState());

  final GetCourseAttendanceUseCase _getAnalytics;
  final ListAttendanceSessionsUseCase _listSessions;
  final String courseId;

  String? _status;
  int _page = 1;

  String? get statusFilter => _status;

  Future<void> load({bool refresh = false}) async {
    if (isClosed) return;
    emit(state.copyWith(
      status: RemoteStatus.loading,
      isRefreshing: refresh,
      clearFailure: true,
    ));

    // Both requests overlap; the tiles and the table load together.
    final analyticsFuture = _getAnalytics(IdParams(courseId));
    final sessionsFuture = _listSessions(
      AttendanceSessionParams(courseId: courseId, status: _status, page: _page),
    );

    final analytics = await analyticsFuture;
    final sessions = await sessionsFuture;
    if (isClosed) return;

    final failure = analytics.fold((f) => f, (_) => null) ??
        sessions.fold((f) => f, (_) => null);
    if (failure != null) {
      emit(state.copyWith(
        status: RemoteStatus.failure,
        failure: failure,
        isRefreshing: false,
      ));
      return;
    }

    emit(
      RemoteState(
        status: RemoteStatus.success,
        data: CourseAttendanceData(
          analytics: analytics.getOrElse(() => CourseAttendance.empty),
          sessions: sessions.getOrElse(Paginated.emptyOf<AttendanceSession>),
        ),
      ),
    );
  }

  /// Changing the status filter restarts at page 1, as the React select does.
  Future<void> setStatus(String? status) {
    _status = status;
    _page = 1;
    return load();
  }

  Future<void> setPage(int page) {
    _page = page;
    return load();
  }
}
