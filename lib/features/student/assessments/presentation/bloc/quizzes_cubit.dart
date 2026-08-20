import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../../../../core/network/api_response.dart';
import '../../../courses/domain/usecases/course_usecases.dart';
import '../../domain/entities/student_assessment.dart';
import '../../domain/usecases/list_course_assessments_usecase.dart';

/// The standalone Quizzes list — every quiz across the student's enrolled
/// courses, the port of `AssessmentListPage` with `category="quiz"`.
///
/// The web page paginates with numbered pages; this uses the app's infinite
/// scroll instead, so [loadMore] appends rather than replaces.
class QuizzesCubit extends Cubit<RemoteState<Paginated<StudentAssessment>>> {
  QuizzesCubit({
    required ListAllAssessmentsUseCase listAll,
    required ListEnrolledCoursesUseCase listCourses,
  })  : _listAll = listAll,
        _listCourses = listCourses,
        super(const RemoteState());

  final ListAllAssessmentsUseCase _listAll;
  final ListEnrolledCoursesUseCase _listCourses;

  /// Seeded with the category that makes this the *Quizzes* screen. Dropping it
  /// does not empty the list — it silently fills it with assignments.
  AssessmentQueryParams _query = const AssessmentQueryParams(category: 'quiz');

  bool _isLoadingMore = false;
  List<AssessmentCourseRef>? _courses;

  /// Not part of the emitted state: the query is what the *next* request will
  /// ask for, and the state is what the last one returned.
  AssessmentQueryParams get query => _query;

  bool get hasMore => state.data?.pagination.hasNextPage ?? false;
  bool get isLoadingMore => _isLoadingMore;

  Future<void> load({bool refresh = false}) async {
    if (isClosed) return;
    emit(state.copyWith(
      status: RemoteStatus.loading,
      isRefreshing: refresh,
      clearFailure: true,
    ));

    final result = await _listAll(_query.copyWith(page: 1));
    if (isClosed) return;

    result.fold(
      (failure) => emit(state.copyWith(
        status: RemoteStatus.failure,
        failure: failure,
        isRefreshing: false,
      )),
      (page) => emit(RemoteState(status: RemoteStatus.success, data: page)),
    );
  }

  Future<void> loadMore() async {
    if (isClosed || _isLoadingMore || !hasMore) return;
    _isLoadingMore = true;

    final current = state.data!;
    final result = await _listAll(
      _query.copyWith(page: current.pagination.page + 1),
    );

    _isLoadingMore = false;
    if (isClosed) return;

    result.fold(
      // Keep what's already on screen; the footer just stops advancing.
      (failure) => emit(state.copyWith(failure: failure)),
      (next) => emit(state.copyWith(data: current.copyWithAppended(next))),
    );
  }

  /// Every filter change restarts from page 1.
  Future<void> setSearch(String value) {
    _query = _query.copyWith(search: value);
    return load();
  }

  /// Applies course and status together in one reload.
  ///
  /// The sheet stages both and commits on Apply; calling two setters in
  /// sequence would fire two requests and paint a throwaway result set on the
  /// way. Nulls mean "no filter" — the sheet always submits the complete set,
  /// so this cannot be mistaken for "leave unchanged".
  Future<void> setFilters({String? courseId, String? status}) {
    _query = _query.copyWith(
      courseId: courseId,
      status: status,
      clearCourse: courseId == null,
      clearStatus: status == null,
    );
    return load();
  }

  /// Options for the course filter, fetched on first use and cached.
  ///
  /// Deliberately lazy: the sheet is what needs them, and loading them with the
  /// page would cost a second request on every visit for a filter most students
  /// never open. If the request fails, the courses already present in the
  /// loaded quizzes stand in — a partial list beats an empty filter.
  Future<List<AssessmentCourseRef>> courseOptions() async {
    final cached = _courses;
    if (cached != null) return cached;

    final result = await _listCourses(const ListCoursesParams(limit: 100));
    if (isClosed) return const [];

    return result.fold(
      (_) => _coursesFromLoadedQuizzes(),
      (page) {
        final courses = [
          for (final enrollment in page.items)
            AssessmentCourseRef(
              id: enrollment.course.id,
              name: enrollment.course.name,
              code: enrollment.course.code,
              colorCode: enrollment.course.colorCode,
            ),
        ];
        _courses = courses;
        return courses;
      },
    );
  }

  List<AssessmentCourseRef> _coursesFromLoadedQuizzes() {
    final byId = <String, AssessmentCourseRef>{};
    for (final quiz in state.data?.items ?? const <StudentAssessment>[]) {
      final course = quiz.course;
      if (course != null) byId[course.id] = course;
    }
    return byId.values.toList(growable: false);
  }
}
