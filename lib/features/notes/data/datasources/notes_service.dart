import '../../../../core/constants/api_urls.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/entities/note.dart';
import '../models/note_model.dart';

/// Raw HTTP for the notes endpoints — the port of `src/api/notes`.
///
/// Covers the feed, one note, the write operations and the like toggle.
/// Comments, sharing and attachment upload are a later pass; their counts still
/// come back on every row.
class NotesService {
  const NotesService(this._client);

  final DioClient _client;

  /// `GET /notes` — the feed, filtered every way the hub and the embedded tabs
  /// need.
  ///
  /// `q` matches the title **and** the content server-side; `tag` is an exact,
  /// case-sensitive array match.
  Future<Paginated<NoteListItemModel>> listNotes({
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
  }) async {
    final response = await _client.get(
      ApiUrls.notes,
      query: {
        'q': query,
        'sort': sort,
        // Sent only when true: the server reads their presence, and sending
        // both at once returns nothing at all.
        if (mine) 'mine': true,
        if (shared) 'shared': true,
        'visibility': visibility,
        'tag': tag,
        'materialId': materialId,
        'questionId': questionId,
        'courseId': courseId,
        'page': page,
        'limit': limit,
      },
      parse: (data) => Paginated<NoteListItemModel>.fromJson(
        data,
        NoteListItemModel.fromJson,
      ),
    );
    return response.data;
  }

  /// `GET /notes/:id`.
  ///
  /// Increments the note's view count for anyone but its author, so this is not
  /// a free read — do not call it to refresh a row.
  Future<NoteDetailModel> getNote(String id) async {
    final response = await _client.get(
      ApiUrls.note(id),
      parse: (data) => NoteDetailModel.fromJson(
        (data as Map<String, dynamic>?) ?? const {},
      ),
    );
    return response.data;
  }

  /// `POST /notes` — returns the new note's id.
  ///
  /// The response is the raw row, missing everything a card renders, so only
  /// the id is worth reading back.
  Future<String> createNote(CreateNoteInput input) async {
    final response = await _client.post(
      ApiUrls.notes,
      body: input.toJson(),
      parse: noteIdFromJson,
    );
    return response.data;
  }

  /// `PATCH /notes/:id` — owner only.
  ///
  /// Returns nothing useful for the same reason as create, so the caller
  /// reloads instead of splicing.
  Future<void> updateNote(UpdateNoteInput input) => _client.patch(
        ApiUrls.note(input.id),
        body: input.toJson(),
        parse: (_) => null,
      );

  /// `DELETE /notes/:id` — hard delete; likes and comments cascade away.
  Future<void> deleteNote(String id) =>
      _client.delete(ApiUrls.note(id), parse: (_) => null);

  /// `POST /notes/:id/like` — toggles, and answers with the recounted total.
  Future<NoteLikeResultModel> toggleLike(String id) async {
    final response = await _client.post(
      ApiUrls.noteLike(id),
      parse: NoteLikeResultModel.fromJson,
    );
    return response.data;
  }

  /// `GET /notes/my-stats`.
  Future<MyNotesStatsModel> getMyStats() async {
    final response = await _client.get(
      ApiUrls.notesMyStats,
      parse: MyNotesStatsModel.fromJson,
    );
    return response.data;
  }
}
