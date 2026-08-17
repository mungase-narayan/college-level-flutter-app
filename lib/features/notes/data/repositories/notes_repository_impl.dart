import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/guard.dart';
import '../../../../core/network/api_response.dart';
import '../../domain/entities/note.dart';
import '../../domain/repositories/notes_repository.dart';
import '../datasources/notes_service.dart';

class NotesRepositoryImpl with RepositoryGuard implements NotesRepository {
  const NotesRepositoryImpl(this._service);

  final NotesService _service;

  @override
  Future<Either<Failure, Paginated<NoteListItem>>> listNotes({
    String? query,
    String sort = 'recent',
    bool mine = false,
    bool shared = false,
    String? visibility,
    String? tag,
    String? materialId,
    String? questionId,
    String? courseId,
    int page = 1,
    int limit = NoteMeta.pageSize,
  }) =>
      guard(() async {
        final result = await _service.listNotes(
          query: query,
          sort: sort,
          mine: mine,
          shared: shared,
          visibility: visibility,
          tag: tag,
          materialId: materialId,
          questionId: questionId,
          courseId: courseId,
          page: page,
          limit: limit,
        );
        return Paginated<NoteListItem>(
          items: result.items,
          pagination: result.pagination,
        );
      });

  @override
  Future<Either<Failure, NoteDetail>> getNote(String id) =>
      guard(() => _service.getNote(id));

  @override
  Future<Either<Failure, String>> createNote(CreateNoteInput input) =>
      guard(() => _service.createNote(input));

  @override
  Future<Either<Failure, Unit>> updateNote(UpdateNoteInput input) =>
      guard(() async {
        await _service.updateNote(input);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> deleteNote(String id) => guard(() async {
        await _service.deleteNote(id);
        return unit;
      });

  @override
  Future<Either<Failure, NoteLikeResult>> toggleLike(String id) =>
      guard(() => _service.toggleLike(id));

  @override
  Future<Either<Failure, MyNotesStats>> getMyStats() =>
      guard(_service.getMyStats);
}
