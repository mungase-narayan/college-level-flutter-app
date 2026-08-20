import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/network/api_response.dart';
import '../entities/note.dart';

abstract class NotesRepository {
  Future<Either<Failure, Paginated<NoteListItem>>> listNotes({
    String? query,
    String sort,
    bool mine,
    bool shared,
    String? visibility,
    String? tag,
    String? materialId,
    String? questionId,
    String? courseId,
    int page,
    int limit,
  });

  Future<Either<Failure, NoteDetail>> getNote(String id);

  /// The new note's id — the create response carries nothing else worth having.
  Future<Either<Failure, String>> createNote(CreateNoteInput input);

  Future<Either<Failure, Unit>> updateNote(UpdateNoteInput input);

  Future<Either<Failure, Unit>> deleteNote(String id);

  Future<Either<Failure, NoteLikeResult>> toggleLike(String id);

  Future<Either<Failure, MyNotesStats>> getMyStats();
}
