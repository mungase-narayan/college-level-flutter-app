import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/common/bloc/remote_cubit.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/practice_question.dart';
import '../../domain/usecases/practice_usecases.dart';

/// The practice question bank list, with the server-side filters the React
/// `PracticeFilters` exposes and infinite scroll in place of the desktop
/// paginator.
class PracticeListCubit extends Cubit<RemoteState<Paginated<PracticeQuestionListItem>>> {
  PracticeListCubit({
    required ListPracticeQuestionsUseCase listQuestions,
    required SetBookmarkedUseCase setBookmarked,
    required GetPracticeFiltersUseCase getFilters,
  })  : _listQuestions = listQuestions,
        _setBookmarked = setBookmarked,
        _getFilters = getFilters,
        super(const RemoteState());

  final ListPracticeQuestionsUseCase _listQuestions;
  final SetBookmarkedUseCase _setBookmarked;
  final GetPracticeFiltersUseCase _getFilters;

  List<PracticeSubject>? _courses;

  PracticeQueryParams _query = const PracticeQueryParams();
  bool _isLoadingMore = false;

  PracticeQueryParams get query => _query;
  bool get hasMore => state.data?.pagination.hasNextPage ?? false;
  bool get isLoadingMore => _isLoadingMore;

  Future<void> load({bool refresh = false}) async {
    if (isClosed) return;
    emit(state.copyWith(
      status: RemoteStatus.loading,
      isRefreshing: refresh,
      clearFailure: true,
    ));

    final result = await _listQuestions(_query.copyWith(page: 1));
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
    final result = await _listQuestions(
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

  Future<void> setType(String? type) {
    _query = type == null
        ? _query.copyWith(clearType: true)
        : _query.copyWith(type: type);
    return load();
  }

  Future<void> setDifficulty(String? difficulty) {
    _query = difficulty == null
        ? _query.copyWith(clearDifficulty: true)
        : _query.copyWith(difficulty: difficulty);
    return load();
  }

  Future<void> setAttemptStatus(String? status) {
    _query = status == null
        ? _query.copyWith(clearAttemptStatus: true)
        : _query.copyWith(attemptStatus: status);
    return load();
  }

  Future<void> setBookmarkedOnly(bool? value) {
    _query = value == null || !value
        ? _query.copyWith(clearBookmarked: true)
        : _query.copyWith(bookmarked: true);
    return load();
  }

  Future<void> setSort(String sort) {
    _query = _query.copyWith(sort: sort);
    return load();
  }

  /// The Course options, fetched once on first use.
  ///
  /// Lazy for the same reason the quiz screen's are: the sheet is what needs
  /// them, and most visits never open it.
  Future<List<PracticeSubject>> courseOptions() async {
    final cached = _courses;
    if (cached != null) return cached;

    final result = await _getFilters(const NoParams());
    if (isClosed) return const [];

    return result.fold(
      // A filter that will not load is not worth an error banner over the
      // list; the other filters still work.
      (_) => const [],
      (options) {
        _courses = options.subjects;
        return options.subjects;
      },
    );
  }

  /// Applies every filter the sheet owns in one reload.
  ///
  /// The sheet stages them all and commits on Apply. Calling the individual
  /// setters in sequence would fire one request each and paint several
  /// throwaway result sets before landing on the one the user asked for.
  ///
  /// Nulls mean "no filter", so this cannot express "leave unchanged" — the sheet
  /// always submits the complete set, which is what makes that unambiguous.
  Future<void> setFilters({
    required String sort,
    String? attemptStatus,
    String? difficulty,
    String? type,
    String? courseId,
    bool bookmarked = false,
  }) {
    _query = _query.copyWith(
      sort: sort,
      attemptStatus: attemptStatus,
      difficulty: difficulty,
      type: type,
      courseId: courseId,
      // `false` and "no filter" are the same thing here: the endpoint has no
      // "not bookmarked" mode, and the web never sends one either.
      bookmarked: bookmarked ? true : null,
      clearAttemptStatus: attemptStatus == null,
      clearDifficulty: difficulty == null,
      clearType: type == null,
      clearCourse: courseId == null,
      clearBookmarked: !bookmarked,
    );
    return load();
  }

  /// Optimistically flips the bookmark, reverting if the write fails.
  Future<void> toggleBookmark(PracticeQuestionListItem question) async {
    final current = state.data;
    if (current == null || isClosed) return;

    final target = !question.bookmarked;
    emit(state.copyWith(data: _withBookmark(current, question.id, target)));

    final result = await _setBookmarked(
      SetBookmarkedParams(questionId: question.id, bookmarked: target),
    );
    if (isClosed) return;

    result.fold(
      (failure) => emit(
        state.copyWith(
          data: _withBookmark(current, question.id, question.bookmarked),
          failure: failure,
        ),
      ),
      (_) {
        // When filtering to bookmarks only, un-bookmarking should drop the row.
        if (_query.bookmarked == true && !target) load(refresh: true);
      },
    );
  }

  Paginated<PracticeQuestionListItem> _withBookmark(
    Paginated<PracticeQuestionListItem> page,
    String questionId,
    bool bookmarked,
  ) =>
      Paginated<PracticeQuestionListItem>(
        pagination: page.pagination,
        items: [
          for (final item in page.items)
            if (item.id == questionId)
              PracticeQuestionListItem(
                id: item.id,
                title: item.title,
                type: item.type,
                difficulty: item.difficulty,
                points: item.points,
                bookmarked: bookmarked,
                stats: item.stats,
                questionNumber: item.questionNumber,
                duration: item.duration,
                tags: item.tags,
                courseId: item.courseId,
                subject: item.subject,
                moduleName: item.moduleName,
                topicName: item.topicName,
                totalAttempts: item.totalAttempts,
              )
            else
              item,
        ],
      );
}
