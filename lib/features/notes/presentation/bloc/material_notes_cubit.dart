import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/common/bloc/remote_cubit.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/note.dart';
import '../../domain/usecases/notes_usecases.dart';

/// The notes filed against one material — the port of `NotesSection`'s
/// `useNotes({ materialId, sort: 'recent', limit: 30 })`.
class MaterialNotesCubit extends Cubit<RemoteState<List<NoteListItem>>> {
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

    final result = await _list(ListNotesParams(materialId: link.materialId));
    if (isClosed) return;

    result.fold(
      (failure) => emit(state.copyWith(
        status: RemoteStatus.failure,
        failure: failure,
        isRefreshing: false,
      )),
      (notes) => emit(RemoteState(status: RemoteStatus.success, data: notes)),
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
