import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../../../../core/error/failures.dart';
import '../../../../../core/network/api_response.dart';
import '../../domain/entities/note.dart';
import '../../domain/usecases/notes_usecases.dart';

/// The notes filed against one material — the port of `NotesSection`'s
/// `useNotes({ materialId, sort: 'recent', limit: 30 })`.
class MaterialNotesCubit
    extends Cubit<RemoteState<Paginated<NoteListItem>>> {
  MaterialNotesCubit({
    required ListNotesUseCase list,
    required CreateNoteUseCase create,
    required this.link,
  })  : _list = list,
        _create = create,
        super(const RemoteState());

  final ListNotesUseCase _list;
  final CreateNoteUseCase _create;

  /// What new notes are linked to, and what the list is filtered by.
  final NoteLinkContext link;

  bool _submitting = false;

  bool get isSubmitting => _submitting;

  Future<void> load({bool refresh = false}) async {
    if (isClosed) return;
    emit(state.copyWith(
      status: RemoteStatus.loading,
      isRefreshing: refresh,
      clearFailure: true,
    ));

    final result = await _list(
      ListNotesParams(
        materialId: link.materialId,
        // Sending the question too is what makes a question-scoped tab actually
        // scoped: without it the request carried no filter at all and listed
        // every note in the school.
        questionId: link.questionId,
        // Only when there is nothing narrower. A note filed against a material
        // always carries that material's course, so adding it narrows nothing —
        // but it would drop a note whose course was never set.
        courseId: link.materialId == null && link.questionId == null
            ? link.courseId
            : null,
        // Explicit, because the shared default is now the hub's smaller page.
        limit: NoteMeta.embeddedPageSize,
      ),
    );
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

  /// Creates a note pre-linked to this material, then reloads the list.
  /// Returns the failure so the caller can toast it.
  Future<Failure?> create({
    required String title,
    required String content,
    required List<String> tags,
    required String visibility,
  }) async {
    if (_submitting) return null;
    _submitting = true;

    final result = await _create(
      CreateNoteInput(
        title: title,
        content: content,
        link: link,
        tags: tags,
        visibility: visibility,
      ),
    );

    _submitting = false;
    if (isClosed) return null;

    final failure = result.fold((f) => f, (_) => null);
    if (failure == null) await load(refresh: true);
    return failure;
  }
}
