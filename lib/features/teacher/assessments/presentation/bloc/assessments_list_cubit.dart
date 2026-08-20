import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../../../../core/error/failures.dart';
import '../../domain/entities/teacher_assessment.dart';
import '../../domain/usecases/teacher_assessment_usecases.dart';

/// One assessment list, filtered to either assignments or quizzes.
///
/// Both tabs issue the **same** request — there is no server-side category
/// filter — so each cubit fetches the course's assessments and keeps the half
/// it owns. Search and paging are local for the same reason.
class AssessmentsListCubit extends Cubit<RemoteState<List<TeacherAssessment>>> {
  AssessmentsListCubit({
    required TeacherAssessmentUseCases assessments,
    required this.courseId,
    required this.quizzes,
    this.divisionId,
    this.courseMaterialId,
  })  : _assessments = assessments,
        super(const RemoteState());

  final TeacherAssessmentUseCases _assessments;
  final String courseId;

  /// Null for the material panel, which scopes by material instead — an
  /// assignment published against a material reaches every section.
  final String? divisionId;

  /// Which half of the payload this list owns.
  final bool quizzes;

  /// Set by the Learning Plan panel to narrow to one material's assignments.
  final String? courseMaterialId;

  static const pageSize = 10;

  List<TeacherAssessment> _all = const [];
  String _search = '';
  int _page = 1;

  String get search => _search;
  int get page => _page;

  /// The noun this list is about, used throughout its copy so the Quiz tab
  /// never says "assignment" — which the web's does.
  String get noun => quizzes ? 'quiz' : 'assignment';
  String get nounPlural => quizzes ? 'quizzes' : 'assignments';

  /// Everything in this tab's category, before the search.
  List<TeacherAssessment> get owned =>
      [for (final a in _all) if (a.isQuiz == quizzes) a];

  List<TeacherAssessment> get matching => [
        for (final a in owned)
          if (_search.isEmpty || a.title.toLowerCase().contains(_search)) a,
      ];

  int get totalPages => (matching.length / pageSize).ceil().clamp(1, 9999);

  /// The current page, clamped so a search that shortens the list cannot
  /// strand the reader past the end of it.
  List<TeacherAssessment> get visible {
    final rows = matching;
    final start = (_page.clamp(1, totalPages) - 1) * pageSize;
    return rows.skip(start).take(pageSize).toList(growable: false);
  }

  /// Whether this tab has nothing of its own *at all*, as opposed to nothing
  /// matching the search.
  ///
  /// The web's Assignments tab tests the whole unfiltered payload here, so a
  /// course holding only quizzes tells the teacher "no matches" instead of
  /// offering to create the first assignment. This tests the owned half.
  bool get isEmptyCategory => owned.isEmpty;

  Future<void> load({bool refresh = false}) async {
    if (isClosed) return;
    emit(state.copyWith(
      status: RemoteStatus.loading,
      isRefreshing: refresh,
      clearFailure: true,
    ));

    final result = await _assessments.list(
      courseId: courseId,
      divisionId: divisionId,
      courseMaterialId: courseMaterialId,
    );
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
    _search = value.trim().toLowerCase();
    _page = 1;
    if (!isClosed && state.isSuccess) emit(state.copyWith(data: _all));
  }

  void setPage(int value) {
    _page = value;
    if (!isClosed && state.isSuccess) emit(state.copyWith(data: _all));
  }

  Future<Failure?> delete(String id) async {
    final result = await _assessments.delete(id);
    if (isClosed) return null;

    final failure = result.fold<Failure?>((f) => f, (_) => null);
    if (failure == null) await load(refresh: true);
    return failure;
  }
}
