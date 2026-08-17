import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/guard.dart';
import '../../domain/entities/note.dart';
import '../../domain/repositories/notes_repository.dart';
import '../datasources/notes_service.dart';

class NotesRepositoryImpl with RepositoryGuard implements NotesRepository {
  const NotesRepositoryImpl(this._service);

  final NotesService _service;

  @override
  Future<Either<Failure, List<NoteListItem>>> listNotes({
    String? materialId,
    String? courseId,
    String sort = 'recent',
    int limit = 30,
  }) =>
      guard(
        () => _service.listNotes(
          materialId: materialId,
          courseId: courseId,
          sort: sort,
          limit: limit,
        ),
      );

  @override
  Future<Either<Failure, NoteListItem>> createNote(CreateNoteInput input) =>
      guard(() => _service.createNote(input));
}
