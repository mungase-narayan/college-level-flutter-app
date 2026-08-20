import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../../../../core/error/failures.dart';
import '../../../../../core/network/api_response.dart';
import '../../../../../core/usecases/usecase.dart';
import '../../domain/entities/note.dart';
import '../../domain/usecases/notes_usecases.dart';

/// The notes feed — the port of `NotesListPage`.
class NotesHubCubit extends Cubit<RemoteState<Paginated<NoteListItem>>> {
  NotesHubCubit({
    required ListNotesUseCase list,
    required CreateNoteUseCase create,
    required ToggleNoteLikeUseCase toggleLikeUseCase,
    required DeleteNoteUseCase deleteUseCase,
  })  : _list = list,
        _create = create,
        _toggleLike = toggleLikeUseCase,
        _delete = deleteUseCase,
        super(const RemoteState());

  final ListNotesUseCase _list;
  final CreateNoteUseCase _create;
  final ToggleNoteLikeUseCase _toggleLike;
  final DeleteNoteUseCase _delete;

  ListNotesParams _query = const ListNotesParams();
  NotesTab _tab = NotesTab.all;
  bool _isLoadingMore = false;

  /// Ids with a like in flight. Without this a double tap fires two toggles,
  /// which cancel each other out and leave the row where it started.
  final _liking = <String>{};

  /// Not part of the emitted state: the query is what the *next* request will
  /// ask for, and the state is what the last one returned.
  ListNotesParams get query => _query;
  NotesTab get tab => _tab;

  bool get hasMore => state.data?.pagination.hasNextPage ?? false;
  bool get isLoadingMore => _isLoadingMore;

  /// Folds the tab into the query at request time.
  ///
  /// The tab is deliberately not stored on [_query]: keeping `visibility` there
  /// while nulling it off the "mine" tab is what lets a student's choice
  /// survive a trip through another tab, which is what the web does.
  ListNotesParams _effective(int page) => _query.copyWith(
        page: page,
        mine: _tab == NotesTab.mine,
        shared: _tab == NotesTab.shared,
        // The control only exists on "mine", and the server already hides other
        // people's private notes.
        clearVisibility: _tab != NotesTab.mine,
      );

  Future<void> load({bool refresh = false}) async {
    if (isClosed) return;
    emit(state.copyWith(
      status: RemoteStatus.loading,
      isRefreshing: refresh,
      clearFailure: true,
    ));

    // Always page 1, so any filter change restarts the feed.
    final result = await _list(_effective(1));
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
    final result = await _list(_effective(current.pagination.page + 1));

    _isLoadingMore = false;
    if (isClosed) return;

    result.fold(
      // Keep what's already on screen; the footer just stops advancing.
      (failure) => emit(state.copyWith(failure: failure)),
      (next) => emit(state.copyWith(data: current.copyWithAppended(next))),
    );
  }

  Future<void> setTab(NotesTab tab) {
    if (tab == _tab) return Future.value();
    _tab = tab;
    return load();
  }

  Future<void> setSearch(String value) {
    final trimmed = value.trim();
    final next = trimmed.isEmpty ? null : trimmed;
    // The field fires on every debounced keystroke, including ones that leave
    // the term unchanged after trimming.
    if (next == _query.query) return Future.value();

    _query = _query.copyWith(query: next, clearQuery: next == null);
    return load();
  }

  Future<void> setSort(String sort) {
    if (sort == _query.sort) return Future.value();
    _query = _query.copyWith(sort: sort);
    return load();
  }

  Future<void> setVisibility(String? visibility) {
    if (visibility == _query.visibility) return Future.value();
    _query = _query.copyWith(
      visibility: visibility,
      clearVisibility: visibility == null,
    );
    return load();
  }

  /// Passed through exactly as it arrived: the server matches tags literally
  /// and case-sensitively, so a tag is only ever set by tapping a real one.
  Future<void> setTag(String? tag) {
    if (tag == _query.tag) return Future.value();
    _query = _query.copyWith(tag: tag, clearTag: tag == null);
    return load();
  }

  Future<void> clearFilters() {
    if (!_query.hasFilters) return Future.value();
    _query = _query.copyWith(
      clearQuery: true,
      clearTag: true,
      clearVisibility: true,
    );
    return load();
  }

  /// Toggles a like and patches that one row from the server's answer.
  ///
  /// Server-authoritative rather than optimistic, for the reason
  /// `DiscussionCubit.react` records: the toggle lives on the server, so the
  /// true count only arrives with the response. Patching the row beats
  /// reloading the list, which would throw away every page after the first.
  Future<Failure?> toggleLike(String id) async {
    if (isClosed || _liking.contains(id)) return null;
    _liking.add(id);

    final result = await _toggleLike(IdParams(id));

    _liking.remove(id);
    if (isClosed) return null;

    return result.fold((failure) => failure, (like) {
      final current = state.data;
      if (current == null) return null;

      emit(state.copyWith(
        data: Paginated<NoteListItem>(
          items: [
            for (final note in current.items)
              if (note.id == id)
                note.copyWithLike(liked: like.liked, likeCount: like.likeCount)
              else
                note,
          ],
          pagination: current.pagination,
        ),
      ));
      return null;
    });
  }

  /// Returns the new note's id, so the caller can open it.
  Future<Either<Failure, String>> create(CreateNoteInput input) async {
    final result = await _create(input);
    if (isClosed) return result;

    return result.fold(Left.new, (id) {
      load(refresh: true);
      return Right(id);
    });
  }

  Future<Failure?> deleteNote(String id) async {
    final result = await _delete(IdParams(id));
    if (isClosed) return null;

    final failure = result.fold((f) => f, (_) => null);
    if (failure == null) await load(refresh: true);
    return failure;
  }
}
