import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../domain/entities/submission.dart';
import '../../domain/usecases/teacher_grading_usecases.dart';

/// The learner list on the results screen — server-paged, searched and sorted,
/// unlike the assessment lists which filter what they already hold.
class OverviewCubit extends Cubit<RemoteState<AssignmentOverview>> {
  OverviewCubit({
    required TeacherGradingUseCases grading,
    required this.assessmentId,
  })  : _grading = grading,
        super(const RemoteState());

  final TeacherGradingUseCases _grading;
  final String assessmentId;

  static const pageSize = 15;

  /// The four orderings the web offers, as one value so the control is a
  /// single select rather than two.
  static const sortScoreDesc = 'score-desc';
  static const sortScoreAsc = 'score-asc';
  static const sortNameAsc = 'name-asc';
  static const sortNameDesc = 'name-desc';

  static const sortOptions = [
    sortScoreDesc,
    sortScoreAsc,
    sortNameAsc,
    sortNameDesc,
  ];

  static String sortLabel(String value) => switch (value) {
        sortScoreDesc => 'Score: high → low',
        sortScoreAsc => 'Score: low → high',
        sortNameAsc => 'Name: A → Z',
        sortNameDesc => 'Name: Z → A',
        _ => value,
      };

  Timer? _debounce;

  String _search = '';
  String _sort = sortScoreDesc;
  int _page = 1;

  String get search => _search;
  String get sort => _sort;
  int get page => _page;

  Future<void> load({bool refresh = false}) async {
    if (isClosed) return;
    emit(state.copyWith(
      status: RemoteStatus.loading,
      isRefreshing: refresh,
      clearFailure: true,
    ));

    final parts = _sort.split('-');
    final result = await _grading.overview(
      assessmentId: assessmentId,
      page: _page,
      limit: pageSize,
      search: _search.isEmpty ? null : _search,
      sortBy: parts.first,
      sortOrder: parts.last,
    );
    if (isClosed) return;

    result.fold(
      (failure) => emit(state.copyWith(
        status: RemoteStatus.failure,
        failure: failure,
        isRefreshing: false,
      )),
      (overview) => emit(
        RemoteState(status: RemoteStatus.success, data: overview),
      ),
    );
  }

  /// Debounced: each keystroke is a request, since the search runs server-side.
  void setSearch(String value) {
    _search = value.trim();
    _page = 1;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), load);
  }

  void setSort(String value) {
    _sort = value;
    _page = 1;
    load();
  }

  void setPage(int value) {
    _page = value;
    load();
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
