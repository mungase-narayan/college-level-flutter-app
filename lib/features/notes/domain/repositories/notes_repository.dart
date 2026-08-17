import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/note.dart';

abstract class NotesRepository {
  Future<Either<Failure, List<NoteListItem>>> listNotes({
    String? materialId,
    String? courseId,
    String sort,
    int limit,
  });

  Future<Either<Failure, NoteListItem>> createNote(CreateNoteInput input);
}
