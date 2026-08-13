import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/note.dart';
import '../repositories/notes_repository.dart';

/// The notes linked to a material (or a course).
class ListNotesUseCase implements UseCase<List<NoteListItem>, ListNotesParams> {
  const ListNotesUseCase(this._repository);

  final NotesRepository _repository;

  @override
  Future<Either<Failure, List<NoteListItem>>> call(ListNotesParams params) =>
      _repository.listNotes(
        materialId: params.materialId,
        courseId: params.courseId,
        sort: params.sort,
        limit: params.limit,
      );
}

class ListNotesParams extends Equatable {
  const ListNotesParams({
    this.materialId,
    this.courseId,
    this.sort = 'recent',
    this.limit = 30,
  });

  final String? materialId;
  final String? courseId;
  final String sort;
  final int limit;

  @override
  List<Object?> get props => [materialId, courseId, sort, limit];
}

class CreateNoteUseCase implements UseCase<NoteListItem, CreateNoteInput> {
  const CreateNoteUseCase(this._repository);

  final NotesRepository _repository;

  @override
  Future<Either<Failure, NoteListItem>> call(CreateNoteInput input) =>
      _repository.createNote(input);
}
