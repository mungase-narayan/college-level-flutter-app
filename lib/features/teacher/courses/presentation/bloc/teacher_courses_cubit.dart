import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../domain/entities/teacher_course.dart';
import '../../domain/usecases/teacher_course_usecases.dart';

/// The assigned-course list.
///
/// The endpoint returns one row per **(course, division)**; this folds them into
/// one [TeacherCourseGroup] per course so a teacher taking three sections sees
/// one card reading "3 sections" rather than the same course three times. The
/// web groups client-side in exactly the same way.
///
/// Only `status` is a server filter. Search and type are applied here, over the
/// already-loaded list, matching the web.
class TeacherCoursesCubit extends Cubit<RemoteState<List<TeacherCourseGroup>>> {
  TeacherCoursesCubit({required ListTeacherCoursesUseCase listCourses})
      : _listCourses = listCourses,
        super(const RemoteState());

  final ListTeacherCoursesUseCase _listCourses;

  List<TeacherAssignedCourse> _all = const [];

  String _search = '';
  String? _status;
  String? _type;

  String get search => _search;
  String? get status => _status;
  String? get type => _type;

  bool get hasFilters =>
      _search.isNotEmpty || _status != null || _type != null;

  Future<void> load({bool refresh = false}) async {
    if (isClosed) return;
    emit(state.copyWith(
      status: RemoteStatus.loading,
      isRefreshing: refresh,
      clearFailure: true,
    ));

    final result = await _listCourses(TeacherCourseListParams(status: _status));
    if (isClosed) return;

    result.fold(
      (failure) => emit(state.copyWith(
        status: RemoteStatus.failure,
        failure: failure,
        isRefreshing: false,
      )),
      (rows) {
        _all = rows;
        emit(RemoteState(status: RemoteStatus.success, data: _grouped()));
      },
    );
  }

  void setSearch(String value) {
    _search = value.trim();
    _reapply();
  }

  void setType(String? value) {
    _type = value;
    _reapply();
  }

  /// Status is the one filter the server owns, so changing it refetches.
  Future<void> setStatus(String? value) {
    _status = value;
    return load();
  }

  void _reapply() {
    if (isClosed || !state.isSuccess) return;
    emit(state.copyWith(data: _grouped()));
  }

  /// Filters, then collapses the per-section rows into one group per course.
  ///
  /// Insertion order is preserved so the server's ordering survives — the web
  /// offers no sort control either.
  List<TeacherCourseGroup> _grouped() {
    final term = _search.toLowerCase();

    final matching = _all.where((row) {
      final course = row.course;
      if (_type != null && course.type != _type) return false;
      if (term.isEmpty) return true;

      return [
        course.name,
        course.code,
        course.department?.name,
        course.division?.label,
      ].any((field) => (field ?? '').toLowerCase().contains(term));
    });

    final groups = <String, List<TeacherAssignedCourse>>{};
    for (final row in matching) {
      groups.putIfAbsent(row.course.id, () => []).add(row);
    }

    return [
      for (final rows in groups.values)
        TeacherCourseGroup(
          assignment: rows.first,
          sections: [
            for (final row in rows)
              row.course.division ?? CourseDivision(id: row.divisionId),
          ],
        ),
    ];
  }
}
