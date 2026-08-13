import 'package:equatable/equatable.dart';

/// A note in the feed — `GET /notes`, the port of `NoteListItem` in
/// `src/types/notes.types.ts`.
///
/// The list endpoint carries a plain-text [excerpt] rather than the full
/// markdown body; the body only comes back from `GET /notes/:id`.
class NoteListItem extends Equatable {
  const NoteListItem({
    required this.id,
    required this.title,
    required this.excerpt,
    required this.visibility,
    required this.authorRole,
    required this.author,
    required this.likeCount,
    required this.commentCount,
    required this.viewCount,
    required this.liked,
    required this.isOwner,
    required this.isEdited,
    this.tags = const [],
    this.attachmentCount = 0,
    this.createdAt,
  });

  final String id;
  final String title;
  final String excerpt;

  /// `private` or `published`. A private note is only visible to its author.
  final String visibility;

  /// `student`, `teacher`, or `admin`.
  final String authorRole;
  final NoteAuthor author;
  final int likeCount;
  final int commentCount;
  final int viewCount;
  final bool liked;
  final bool isOwner;
  final bool isEdited;
  final List<String> tags;
  final int attachmentCount;
  final DateTime? createdAt;

  bool get isPrivate => visibility == 'private';

  @override
  List<Object?> get props => [
        id,
        title,
        excerpt,
        visibility,
        authorRole,
        author,
        likeCount,
        commentCount,
        viewCount,
        liked,
        isOwner,
        isEdited,
        tags,
        attachmentCount,
        createdAt,
      ];
}

class NoteAuthor extends Equatable {
  const NoteAuthor({required this.id, this.fullName, this.avatar});

  final String id;
  final String? fullName;
  final String? avatar;

  String get displayName {
    final name = (fullName ?? '').trim();
    return name.isEmpty ? 'Unknown' : name;
  }

  @override
  List<Object?> get props => [id, fullName, avatar];
}

/// The link a note is filed under. Notes written from a material are filtered
/// by, and created against, its `courseId` + `materialId`.
class NoteLinkContext extends Equatable {
  const NoteLinkContext({this.courseId, this.topicId, this.materialId, this.questionId});

  final String? courseId;
  final String? topicId;
  final String? materialId;
  final String? questionId;

  @override
  List<Object?> get props => [courseId, topicId, materialId, questionId];
}

/// The body of `POST /notes`.
class CreateNoteInput extends Equatable {
  const CreateNoteInput({
    required this.title,
    required this.content,
    required this.link,
    this.tags = const [],
    this.visibility = 'published',
  });

  final String title;

  /// Markdown, so a note can carry the same rich blocks a material can.
  final String content;
  final NoteLinkContext link;
  final List<String> tags;
  final String visibility;

  Map<String, dynamic> toJson() => {
        'title': title,
        'content': content,
        'tags': tags,
        'visibility': visibility,
        'courseId': link.courseId,
        'topicId': link.topicId,
        'materialId': link.materialId,
        'questionId': link.questionId,
      };

  @override
  List<Object?> get props => [title, content, link, tags, visibility];
}
