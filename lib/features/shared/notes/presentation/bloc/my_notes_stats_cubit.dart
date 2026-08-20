import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../../../../core/usecases/usecase.dart';
import '../../domain/entities/note.dart';
import '../../domain/usecases/notes_usecases.dart';

/// The four tallies over the student's own notes.
///
/// Its own cubit because it is its own endpoint: a failing stats call must not
/// blank the feed beside it, and the feed's filters have nothing to say to it.
/// The page loads it lazily, the first time "My notes" is opened.
class MyNotesStatsCubit extends RemoteCubit<MyNotesStats> {
  MyNotesStatsCubit({required GetMyNotesStatsUseCase getStats})
      : super(() => getStats(const NoParams()));
}
