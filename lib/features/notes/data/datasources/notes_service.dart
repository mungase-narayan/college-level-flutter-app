import '../../../../core/constants/api_urls.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/entities/note.dart';
import '../models/note_model.dart';

/// Raw HTTP for the notes endpoints — the port of `src/api/notes`.
///
/// Only the two calls the material tab needs are implemented: listing the notes
/// linked to a material and creating one. Likes, comments, sharing, and the
/// notes hub itself are a later pass.
class NotesService {
  const NotesService(this._client);

  final DioClient _client;

  /// `GET /notes?materialId=…&sort=recent&limit=30`.
  ///
  /// The response is the standard paginated envelope; only the rows are needed
  /// here because `NotesSection` on the web also shows a single unpaged list.
  Future<List<NoteListItemModel>> listNotes({
    String? materialId,
    String? courseId,
    String sort = 'recent',
    int limit = 30,
  }) async {
    final response = await _client.get(
      ApiUrls.notes,
      query: {
        'materialId': materialId,
        'courseId': courseId,
        'sort': sort,
        'limit': limit,
      },
      parse: (data) {
        // Tolerates both the paginated envelope and a bare array.
        final rows = data is List
            ? data
            : ((data as Map<String, dynamic>?)?['data'] as List?) ?? const [];
        return rows
            .whereType<Map<String, dynamic>>()
            .map(NoteListItemModel.fromJson)
            .toList(growable: false);
      },
    );
    return response.data;
  }

  /// `POST /notes` — the link context travels in the body, so the new note is
  /// filed against this material from the moment it is created.
  Future<NoteListItemModel> createNote(CreateNoteInput input) async {
    final response = await _client.post(
      ApiUrls.notes,
      body: input.toJson(),
      parse: (data) =>
          NoteListItemModel.fromJson((data as Map<String, dynamic>?) ?? const {}),
    );
    return response.data;
  }
}
