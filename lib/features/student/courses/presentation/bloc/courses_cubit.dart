import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../../../../core/usecases/usecase.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/course_tree.dart';
import '../../domain/usecases/course_usecases.dart';

/// Holds the enrolled-course list plus the client-side filters.
///
/// The React page fetches everything once (`limit: 100`) and then filters by
/// semester and free text **in the browser**; this reproduces that so the
/// filter feels instant and the semester list can be derived from the data.
class CoursesCubit extends Cubit<RemoteState<List<CourseEnrollment>>> {
  CoursesCubit(this._listCourses) : super(const RemoteState());

  final ListEnrolledCoursesUseCase _listCourses;

  List<CourseEnrollment> _all = const [];
  String _search = '';
  String? _semesterId;

  String get search => _search;
  String? get semesterId => _semesterId;

  /// Every semester present in the enrolled set, newest first — the options for
  /// the semester filter.
  List<CourseSemester> get semesters {
    final byId = <String, CourseSemester>{};
    for (final enrollment in _all) {
      final semester = enrollment.course.semester;
      if (semester != null) byId[semester.id] = semester;
    }
    final list = byId.values.toList()..sort((a, b) => b.code.compareTo(a.code));
    return list;
  }

  Future<void> load({bool refresh = false}) async {
    if (isClosed) return;
    emit(state.copyWith(
      status: RemoteStatus.loading,
      isRefreshing: refresh,
      clearFailure: true,
    ));

    final result = await _listCourses(const ListCoursesParams());
    if (isClosed) return;

    result.fold(
      (failure) => emit(state.copyWith(
        status: RemoteStatus.failure,
        failure: failure,
        isRefreshing: false,
      )),
      (page) {
        _all = page.items;
        emit(RemoteState(status: RemoteStatus.success, data: _apply()));
      },
    );
  }

  void setSearch(String value) {
    _search = value;
    _emitFiltered();
  }

  void setSemester(String? id) {
    _semesterId = id;
    _emitFiltered();
  }

  void _emitFiltered() {
    if (isClosed || state.status != RemoteStatus.success) return;
    emit(RemoteState(status: RemoteStatus.success, data: _apply()));
  }

  /// Matches the React filter: semester equality plus a case-insensitive
  /// substring match over course name, code, and department.
  List<CourseEnrollment> _apply() {
    final query = _search.trim().toLowerCase();

    return _all.where((enrollment) {
      final course = enrollment.course;

      if (_semesterId != null && course.semester?.id != _semesterId) return false;
      if (query.isEmpty) return true;

      return course.name.toLowerCase().contains(query) ||
          course.code.toLowerCase().contains(query) ||
          (course.department?.name.toLowerCase().contains(query) ?? false);
    }).toList(growable: false);
  }
}

/// The course detail tree, plus the optimistic material-completion toggle.
class CourseTreeCubit extends Cubit<RemoteState<CourseTree>> {
  CourseTreeCubit({
    required GetCourseTreeUseCase getTree,
    required SetMaterialCompletedUseCase setCompleted,
    required this.courseId,
  })  : _getTree = getTree,
        _setCompleted = setCompleted,
        super(const RemoteState());

  final GetCourseTreeUseCase _getTree;
  final SetMaterialCompletedUseCase _setCompleted;
  final String courseId;

  Future<void> load({bool refresh = false}) async {
    if (isClosed) return;
    emit(state.copyWith(
      status: RemoteStatus.loading,
      isRefreshing: refresh,
      clearFailure: true,
    ));

    final result = await _getTree(IdParams(courseId));
    if (isClosed) return;

    result.fold(
      (failure) => emit(state.copyWith(
        status: RemoteStatus.failure,
        failure: failure,
        isRefreshing: false,
      )),
      (tree) => emit(RemoteState(status: RemoteStatus.success, data: tree)),
    );
  }

  /// Flips completion for one material.
  ///
  /// Applied optimistically so the checkbox responds immediately, then reloaded
  /// from the server so the module/topic/course progress counts — which only
  /// the backend computes — stay authoritative. A failed write reverts.
  Future<void> toggleMaterial(CourseMaterial material) async {
    final tree = state.data;
    if (tree == null || isClosed) return;

    final target = !material.completed;
    emit(state.copyWith(data: _withMaterial(tree, material.id, target)));

    final result = await _setCompleted(
      SetMaterialCompletedParams(materialId: material.id, completed: target),
    );
    if (isClosed) return;

    await result.fold(
      (failure) async {
        emit(state.copyWith(
          data: _withMaterial(tree, material.id, material.completed),
          failure: failure,
        ));
      },
      (_) => load(refresh: true),
    );
  }

  /// Rebuilds the tree with one material's completion flag changed. The
  /// progress counters are left alone — the reload replaces them.
  CourseTree _withMaterial(CourseTree tree, String materialId, bool completed) {
    return CourseTree(
      id: tree.id,
      name: tree.name,
      code: tree.code,
      description: tree.description,
      credits: tree.credits,
      type: tree.type,
      colorCode: tree.colorCode,
      progress: tree.progress,
      modules: [
        for (final module in tree.modules)
          CourseModule(
            id: module.id,
            name: module.name,
            order: module.order,
            description: module.description,
            progress: module.progress,
            topics: [
              for (final topic in module.topics)
                CourseTopic(
                  id: topic.id,
                  name: topic.name,
                  order: topic.order,
                  description: topic.description,
                  progress: topic.progress,
                  materials: [
                    for (final item in topic.materials)
                      item.id == materialId
                          ? item.copyWith(completed: completed)
                          : item,
                  ],
                ),
            ],
          ),
      ],
    );
  }
}
