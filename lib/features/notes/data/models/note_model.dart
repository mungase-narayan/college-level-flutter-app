import '../../domain/entities/note.dart';

String _string(Object? value) => value is String ? value : '';

String? _stringOrNull(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

int _int(Object? value) => (value as num?)?.toInt() ?? 0;

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

/// The fields both the feed row and the detail carry, read once so the two
/// parsers cannot drift apart.
extension _NoteJson on Map<String, dynamic> {
  NoteAuthor get author {
    final raw = this['author'];
    final json = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
    return NoteAuthor(
      id: _string(json['id']),
      fullName: _stringOrNull(json['fullName']),
      avatar: _stringOrNull(json['avatar']),
    );
  }

  List<String> get noteTags =>
      ((this['tags'] as List?) ?? const []).whereType<String>().toList(
            growable: false,
          );

  NoteLinkContext get link => NoteLinkContext(
        courseId: _stringOrNull(this['courseId']),
        topicId: _stringOrNull(this['topicId']),
        materialId: _stringOrNull(this['materialId']),
        questionId: _stringOrNull(this['questionId']),
      );
}

/// JSON → [NoteListItem].
class NoteListItemModel extends NoteListItem {
  const NoteListItemModel({
    required super.id,
    required super.title,
    required super.excerpt,
    required super.visibility,
    required super.authorRole,
    required super.author,
    required super.likeCount,
    required super.commentCount,
    required super.viewCount,
    required super.liked,
    required super.isOwner,
    required super.isEdited,
    super.tags,
    super.link,
    super.createdAt,
    super.updatedAt,
    super.attachmentCount,
  });

  factory NoteListItemModel.fromJson(Map<String, dynamic> json) =>
      NoteListItemModel(
        id: _string(json['id']),
        title: _string(json['title']),
        excerpt: _string(json['excerpt']),
        visibility: json['visibility'] as String? ?? 'published',
        authorRole: json['authorRole'] as String? ?? 'student',
        author: json.author,
        likeCount: _int(json['likeCount']),
        commentCount: _int(json['commentCount']),
        viewCount: _int(json['viewCount']),
        liked: json['liked'] as bool? ?? false,
        isOwner: json['isOwner'] as bool? ?? false,
        isEdited: json['isEdited'] as bool? ?? false,
        tags: json.noteTags,
        link: json.link,
        createdAt: _date(json['createdAt']),
        updatedAt: _date(json['updatedAt']),
        attachmentCount: _int(json['attachmentCount']),
      );
}

/// JSON → [NoteDetail].
class NoteDetailModel extends NoteDetail {
  const NoteDetailModel({
    required super.id,
    required super.title,
    required super.content,
    required super.visibility,
    required super.authorRole,
    required super.author,
    required super.likeCount,
    required super.commentCount,
    required super.viewCount,
    required super.liked,
    required super.isOwner,
    required super.isEdited,
    super.tags,
    super.link,
    super.createdAt,
    super.updatedAt,
    super.attachmentFiles,
  });

  factory NoteDetailModel.fromJson(Map<String, dynamic> json) =>
      NoteDetailModel(
        id: _string(json['id']),
        title: _string(json['title']),
        content: _string(json['content']),
        visibility: json['visibility'] as String? ?? 'published',
        authorRole: json['authorRole'] as String? ?? 'student',
        author: json.author,
        likeCount: _int(json['likeCount']),
        commentCount: _int(json['commentCount']),
        viewCount: _int(json['viewCount']),
        liked: json['liked'] as bool? ?? false,
        isOwner: json['isOwner'] as bool? ?? false,
        isEdited: json['isEdited'] as bool? ?? false,
        tags: json.noteTags,
        link: json.link,
        createdAt: _date(json['createdAt']),
        updatedAt: _date(json['updatedAt']),
        attachmentFiles: ((json['attachmentFiles'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(
              (file) => NoteAttachment(
                id: _string(file['id']),
                url: _string(file['url']),
                name: _string(file['name']),
              ),
            )
            // A file whose url failed to resolve cannot be opened, so it is
            // dropped rather than rendered as a dead row.
            .where((file) => file.url.isNotEmpty)
            .toList(growable: false),
      );
}

/// JSON → [MyNotesStats].
class MyNotesStatsModel extends MyNotesStats {
  const MyNotesStatsModel({
    super.totalViews,
    super.totalLikes,
    super.totalComments,
    super.publishedNotes,
  });

  factory MyNotesStatsModel.fromJson(Object? data) {
    final json = data is Map<String, dynamic> ? data : const <String, dynamic>{};
    return MyNotesStatsModel(
      totalViews: _int(json['totalViews']),
      totalLikes: _int(json['totalLikes']),
      totalComments: _int(json['totalComments']),
      publishedNotes: _int(json['publishedNotes']),
    );
  }
}

/// JSON → [NoteLikeResult].
class NoteLikeResultModel extends NoteLikeResult {
  const NoteLikeResultModel({required super.liked, required super.likeCount});

  factory NoteLikeResultModel.fromJson(Object? data) {
    final json = data is Map<String, dynamic> ? data : const <String, dynamic>{};
    return NoteLikeResultModel(
      liked: json['liked'] as bool? ?? false,
      likeCount: _int(json['likeCount']),
    );
  }
}

/// Reads the id out of the row `POST /notes` answers with.
///
/// That response is the raw database row — no author, no counts, no `isOwner` —
/// so parsing it as a [NoteListItem] would yield a card with a blank author.
/// The id is the only part worth keeping; the caller reloads for the rest.
String noteIdFromJson(Object? data) {
  final json = data is Map<String, dynamic> ? data : const <String, dynamic>{};
  return _string(json['id']);
}
