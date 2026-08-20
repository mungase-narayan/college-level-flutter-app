import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../../../../core/network/api_response.dart';
import '../../domain/entities/bank_question.dart';
import '../../domain/usecases/teacher_assessment_usecases.dart';

/// The question picker's list — server-paged, unlike the assessment lists.
///
/// [assessmentId] is null while creating, which switches the source to the
/// teacher's active questions. That endpoint does not exclude what has already
/// been picked, so [excludedIds] carries the basket and this filters it out.
class QuestionBankCubit extends Cubit<RemoteState<Paginated<BankQuestion>>> {
  QuestionBankCubit({
    required TeacherAssessmentUseCases assessments,
    this.assessmentId,
    Set<String> excludedIds = const {},
  })  : _assessments = assessments,
        _excludedIds = excludedIds,
        super(const RemoteState());

  final TeacherAssessmentUseCases _assessments;
  final String? assessmentId;
  final Set<String> _excludedIds;

  static const pageSize = 8;

  /// Any value the filters treat as "no filter". The API omits the param.
  static const anyValue = 'all';

  Timer? _debounce;

  String _search = '';
  String _type = anyValue;
  String _difficulty = anyValue;
  String _category = anyValue;
  int _page = 1;

  String get search => _search;
  String get type => _type;
  String get difficulty => _difficulty;
  String get category => _category;
  int get page => _page;

  int get totalPages => state.data?.pagination.totalPages ?? 1;

  /// The page, minus anything the basket already holds — only ever non-empty
  /// in create mode, where the source cannot exclude them for us.
  List<BankQuestion> get visible => [
        for (final q in state.data?.items ?? const <BankQuestion>[])
          if (!_excludedIds.contains(q.id)) q,
      ];

  Future<void> load({bool refresh = false}) async {
    if (isClosed) return;
    emit(state.copyWith(
      status: RemoteStatus.loading,
      isRefreshing: refresh,
      clearFailure: true,
    ));

    final result = await _assessments.listBankQuestions(
      assessmentId: assessmentId,
      page: _page,
      limit: pageSize,
      search: _search.isEmpty ? null : _search,
      type: _type == anyValue ? null : _type,
      difficulty: _difficulty == anyValue ? null : _difficulty,
      category: _category == anyValue ? null : _category,
    );
    if (isClosed) return;

    result.fold(
      (failure) => emit(state.copyWith(
        status: RemoteStatus.failure,
        failure: failure,
        isRefreshing: false,
      )),
      (rows) => emit(RemoteState(status: RemoteStatus.success, data: rows)),
    );
  }

  /// Debounced, because every keystroke here is a request — unlike the
  /// assessment lists, which filter what they already hold.
  void setSearch(String value) {
    _search = value.trim();
    _page = 1;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), load);
  }

  void setType(String value) => _setFilter(() => _type = value);
  void setDifficulty(String value) => _setFilter(() => _difficulty = value);
  void setCategory(String value) => _setFilter(() => _category = value);

  void setPage(int value) {
    _page = value;
    load();
  }

  void _setFilter(void Function() apply) {
    apply();
    _page = 1;
    load();
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
