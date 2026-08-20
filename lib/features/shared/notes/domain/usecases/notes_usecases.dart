import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/network/api_response.dart';
import '../../../../../core/usecases/usecase.dart';
import '../entities/note.dart';
import '../repositories/notes_repository.dart';

class ListNotesUseCase
    implements UseCase<Paginated<NoteListItem>, ListNotesParams> {
  const ListNotesUseCase(this._repository);

  final NotesRepository _repository;

  @override
  Future<Either<Failure, Paginated<NoteListItem>>> call(
    ListNotesParams params,
  ) =>
      _repository.listNotes(
        query: params.query,
        sort: params.sort,
        mine: params.mine,
        shared: params.shared,
        visibility: params.visibility,
        tag: params.tag,
        materialId: params.materialId,
        questionId: params.questionId,
        courseId: params.courseId,
        page: params.page,
        limit: params.limit,
      );
}

class GetNoteUseCase implements UseCase<NoteDetail, IdParams> {
  const GetNoteUseCase(this._repository);

  final NotesRepository _repository;

  @override
  Future<Either<Failure, NoteDetail>> call(IdParams params) =>
      _repository.getNote(params.id);
}

class CreateNoteUseCase implements UseCase<String, CreateNoteInput> {
  const CreateNoteUseCase(this._repository);

  final NotesRepository _repository;

  @override
  Future<Either<Failure, String>> call(CreateNoteInput input) =>
      _repository.createNote(input);
}

class UpdateNoteUseCase implements UseCase<Unit, UpdateNoteInput> {
  const UpdateNoteUseCase(this._repository);

  final NotesRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(UpdateNoteInput input) =>
      _repository.updateNote(input);
}

class DeleteNoteUseCase implements UseCase<Unit, IdParams> {
  const DeleteNoteUseCase(this._repository);

  final NotesRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(IdParams params) =>
      _repository.deleteNote(params.id);
}

class ToggleNoteLikeUseCase implements UseCase<NoteLikeResult, IdParams> {
  const ToggleNoteLikeUseCase(this._repository);

  final NotesRepository _repository;

  @override
  Future<Either<Failure, NoteLikeResult>> call(IdParams params) =>
      _repository.toggleLike(params.id);
}

class GetMyNotesStatsUseCase implements UseCase<MyNotesStats, NoParams> {
  const GetMyNotesStatsUseCase(this._repository);

  final NotesRepository _repository;

  @override
  Future<Either<Failure, MyNotesStats>> call(NoParams params) =>
      _repository.getMyStats();
}

/// Everything `GET /notes` can be narrowed by.
class ListNotesParams extends Equatable {
  const ListNotesParams({
    this.query,
    this.sort = 'recent',
    this.mine = false,
    this.shared = false,
    this.visibility,
    this.tag,
    this.materialId,
    this.questionId,
    this.courseId,
    this.page = 1,
    this.limit = NoteMeta.pageSize,
  });

  /// Matches the title **and** the content.
  final String? query;

  /// `recent | oldest | most_liked`.
  final String sort;

  final bool mine;
  final bool shared;

  /// `private | published`, and only meaningful alongside [mine] — the server
  /// already hides other people's private notes.
  final String? visibility;

  /// Matched exactly and case-sensitively, so it is only ever set by tapping a
  /// tag that came back from the server.
  final String? tag;

  final String? materialId;
  final String? questionId;
  final String? courseId;

  final int page;
  final int limit;

  /// The `clear*` flags exist because `??` cannot express "set this to null":
  /// passing `tag: null` to drop the filter would silently keep the old value.
  ListNotesParams copyWith({
    String? query,
    String? sort,
    bool? mine,
    bool? shared,
    String? visibility,
    String? tag,
    String? materialId,
    String? questionId,
    String? courseId,
    int? page,
    int? limit,
    bool clearQuery = false,
    bool clearVisibility = false,
    bool clearTag = false,
  }) =>
      ListNotesParams(
        query: clearQuery ? null : (query ?? this.query),
        sort: sort ?? this.sort,
        mine: mine ?? this.mine,
        shared: shared ?? this.shared,
        visibility: clearVisibility ? null : (visibility ?? this.visibility),
        tag: clearTag ? null : (tag ?? this.tag),
        materialId: materialId ?? this.materialId,
        questionId: questionId ?? this.questionId,
        courseId: courseId ?? this.courseId,
        page: page ?? this.page,
        limit: limit ?? this.limit,
      );

  /// What the user chose, as opposed to which tab they are on — the tab is not
  /// a filter to clear.
  bool get hasFilters =>
      (query ?? '').isNotEmpty || tag != null || visibility != null;

  int get activeFilterCount =>
      ((query ?? '').isNotEmpty ? 1 : 0) +
      (tag != null ? 1 : 0) +
      (visibility != null ? 1 : 0);

  @override
  List<Object?> get props => [
        query,
        sort,
        mine,
        shared,
        visibility,
        tag,
        materialId,
        questionId,
        courseId,
        page,
        limit,
      ];
}
