import '../../domain/entities/note.dart';

/// JSON → [NoteListItem], one row of `GET /notes`.
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
    super.attachmentCount,
    super.createdAt,
  });

  factory NoteListItemModel.fromJson(Map<String, dynamic> json) =>
      NoteListItemModel(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        excerpt: json['excerpt'] as String? ?? '',
        visibility: json['visibility'] as String? ?? 'published',
        authorRole: json['authorRole'] as String? ?? 'student',
        author: _author(json['author']),
        likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
        commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
        viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
        liked: json['liked'] as bool? ?? false,
        isOwner: json['isOwner'] as bool? ?? false,
        isEdited: json['isEdited'] as bool? ?? false,
        attachmentCount: (json['attachmentCount'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
        tags: (json['tags'] as List?)?.whereType<String>().toList(growable: false) ??
            const [],
      );

  static NoteAuthor _author(Object? value) {
    final json = value is Map<String, dynamic> ? value : const <String, dynamic>{};
    return NoteAuthor(
      id: json['id'] as String? ?? '',
      fullName: json['fullName'] as String?,
      avatar: json['avatar'] as String?,
    );
  }
}
