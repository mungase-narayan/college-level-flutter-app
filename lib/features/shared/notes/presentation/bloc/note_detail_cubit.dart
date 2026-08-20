import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../../../../core/error/failures.dart';
import '../../../../../core/usecases/usecase.dart';
import '../../domain/entities/note.dart';
import '../../domain/usecases/notes_usecases.dart';

/// One note, with the three things its owner can do to it.
///
/// The mutations return the [Failure] rather than emitting a failure state, so
/// the page can toast the server's message while leaving the note the student
/// was reading on screen.
class NoteDetailCubit extends RemoteCubit<NoteDetail> {
  NoteDetailCubit({
    required String noteId,
    required GetNoteUseCase getNote,
    required UpdateNoteUseCase updateUseCase,
    required DeleteNoteUseCase deleteUseCase,
    required ToggleNoteLikeUseCase toggleLikeUseCase,
  })  : _id = noteId,
        _update = updateUseCase,
        _delete = deleteUseCase,
        _toggleLike = toggleLikeUseCase,
        super(() => getNote(IdParams(noteId)));

  final String _id;
  final UpdateNoteUseCase _update;
  final DeleteNoteUseCase _delete;
  final ToggleNoteLikeUseCase _toggleLike;

  bool _busy = false;

  /// Server-authoritative, like the hub's — see `NotesHubCubit.toggleLike`.
  Future<Failure?> toggleLike() async {
    final current = state.data;
    if (current == null || isClosed || _busy) return null;
    _busy = true;

    final result = await _toggleLike(IdParams(_id));

    _busy = false;
    if (isClosed) return null;

    return result.fold((failure) => failure, (like) {
      setData(
        current.copyWithLike(liked: like.liked, likeCount: like.likeCount),
      );
      return null;
    });
  }

  /// Saves an edit, then reloads.
  ///
  /// A reload rather than a splice because `PATCH` answers with the raw
  /// database row — no author, no counts — and because the server is what
  /// decides the new `isEdited` and `updatedAt`.
  Future<Failure?> update(UpdateNoteInput input) async {
    if (isClosed) return null;

    final result = await _update(input);
    if (isClosed) return null;

    final failure = result.fold((f) => f, (_) => null);
    if (failure == null) await load(refresh: true);
    return failure;
  }

  Future<Failure?> delete() async {
    if (isClosed) return null;
    final result = await _delete(IdParams(_id));
    return result.fold((failure) => failure, (_) => null);
  }
}
