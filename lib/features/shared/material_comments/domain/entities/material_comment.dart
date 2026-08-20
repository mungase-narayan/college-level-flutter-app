import 'package:equatable/equatable.dart';

/// A comment on a course material — `GET /student/course-materials/:id/comments`.
///
/// Threads are one level deep: the backend rejects a reply to a reply with
/// `COURSE_COMMENT_REPLY_DEPTH`, so [replies] is only ever populated on a
/// top-level comment.
class MaterialComment extends Equatable {
  const MaterialComment({
    required this.id,
    required this.courseMaterialId,
    required this.content,
    required this.authorRole,
    required this.isEdited,
    required this.author,
    this.parentCommentId,
    this.createdAt,
    this.updatedAt,
    this.replies = const [],
  });

  final String id;
  final String courseMaterialId;
  final String? parentCommentId;
  final String content;

  /// `student` or `teacher` — drives the badge next to the name.
  final String authorRole;
  final bool isEdited;
  final CommentAuthor author;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<MaterialComment> replies;

  bool get isReply => parentCommentId != null;

  bool get isTeacher => authorRole == 'teacher';

  /// The wire carries no `isOwner`, so ownership is decided against the signed-in
  /// user — the same check `comment-item.tsx` makes with `currentUserId`.
  bool isOwnedBy(String? userId) =>
      userId != null && userId.isNotEmpty && author.id == userId;

  MaterialComment copyWith({String? content, bool? isEdited}) => MaterialComment(
        id: id,
        courseMaterialId: courseMaterialId,
        parentCommentId: parentCommentId,
        content: content ?? this.content,
        authorRole: authorRole,
        isEdited: isEdited ?? this.isEdited,
        author: author,
        createdAt: createdAt,
        updatedAt: updatedAt,
        replies: replies,
      );

  @override
  List<Object?> get props => [
        id,
        courseMaterialId,
        parentCommentId,
        content,
        authorRole,
        isEdited,
        author,
        createdAt,
        updatedAt,
        replies,
      ];
}

class CommentAuthor extends Equatable {
  const CommentAuthor({required this.id, required this.fullName, this.avatar});

  final String id;
  final String fullName;
  final String? avatar;

  String get displayName => fullName.trim().isEmpty ? 'Unknown' : fullName;

  @override
  List<Object?> get props => [id, fullName, avatar];
}
