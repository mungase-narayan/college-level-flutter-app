import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../../../../core/usecases/usecase.dart';
import '../../domain/entities/teacher_course.dart';
import '../../domain/entities/teacher_course_tree.dart';
import '../../domain/usecases/teacher_course_usecases.dart';

/// The divisions, the selected one, and that section's tree.
class TeacherCourseDetailData extends Equatable {
  const TeacherCourseDetailData({
    required this.divisions,
    required this.divisionId,
    required this.tree,
  });

  final List<CourseDivision> divisions;

  /// Always resolved by the time this exists — nothing below can query without it.
  final String divisionId;
  final TeacherCourseTree tree;

  /// With a single section a picker is just noise, so it is hidden. The web
  /// hides it only at zero, but it has room for a always-on select and a phone
  /// does not.
  bool get showDivisionPicker => divisions.length > 1;

  CourseDivision? get division =>
      divisions.where((d) => d.id == divisionId).firstOrNull;

  @override
  List<Object?> get props => [divisions, divisionId, tree];
}

/// Backs the whole course-detail screen: it resolves the section, loads that
/// section's tree, and every tab reads through it.
///
/// The division lives here rather than in the route, so it resets when the
/// screen is popped — the same lifetime the web's local state has.
class TeacherCourseDetailCubit
    extends Cubit<RemoteState<TeacherCourseDetailData>> {
  TeacherCourseDetailCubit({
    required ListCourseDivisionsUseCase listDivisions,
    required GetTeacherCourseTreeUseCase getTree,
    required this.courseId,
  })  : _listDivisions = listDivisions,
        _getTree = getTree,
        super(const RemoteState());

  final ListCourseDivisionsUseCase _listDivisions;
  final GetTeacherCourseTreeUseCase _getTree;
  final String courseId;

  List<CourseDivision> _divisions = const [];
  String? _divisionId;

  /// The section every tab is scoped to. Null only before the first load lands.
  String? get divisionId => _divisionId;

  Future<void> load({bool refresh = false}) async {
    if (isClosed) return;
    emit(state.copyWith(
      status: RemoteStatus.loading,
      isRefreshing: refresh,
      clearFailure: true,
    ));

    // Divisions first: the tree is meaningless without a section, and the
    // server would otherwise silently pick one for us.
    if (_divisions.isEmpty) {
      final result = await _listDivisions(IdParams(courseId));
      if (isClosed) return;

      final failure = result.fold((f) => f, (_) => null);
      if (failure != null) {
        emit(state.copyWith(
          status: RemoteStatus.failure,
          failure: failure,
          isRefreshing: false,
        ));
        return;
      }
      _divisions = result.getOrElse(() => const []);
      // Default to the teacher's first section, as the web does.
      _divisionId ??= _divisions.firstOrNull?.id;
    }

    await _loadTree();
  }

  /// Reloads the tree for [id] and rescopes every tab with it.
  Future<void> selectDivision(String id) async {
    if (isClosed || id == _divisionId) return;
    _divisionId = id;
    await _loadTree(refresh: state.hasData);
  }

  Future<void> _loadTree({bool refresh = false}) async {
    if (isClosed) return;
    emit(state.copyWith(
      status: RemoteStatus.loading,
      isRefreshing: refresh,
      clearFailure: true,
    ));

    final result = await _getTree(
      CourseTreeParams(courseId: courseId, divisionId: _divisionId),
    );
    if (isClosed) return;

    result.fold(
      (failure) => emit(state.copyWith(
        status: RemoteStatus.failure,
        failure: failure,
        isRefreshing: false,
      )),
      (tree) => emit(
        RemoteState(
          status: RemoteStatus.success,
          data: TeacherCourseDetailData(
            divisions: _divisions,
            // A course with no divisions still renders its tree; the server
            // falls back internally and the picker stays hidden.
            divisionId: _divisionId ?? '',
            tree: tree,
          ),
        ),
      ),
    );
  }

  /// Re-reads the tree after a content mutation.
  ///
  /// Every create/update/delete funnels through here, mirroring the web's
  /// single course-prefix invalidation.
  Future<void> reloadTree() => _loadTree(refresh: true);
}
