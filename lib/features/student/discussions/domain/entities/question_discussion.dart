import 'package:equatable/equatable.dart';

/// A post on a practice question's discussion thread.
///
/// One level deep, like the material comments: a top-level post carries its
/// direct [replies], and a reply carries none.
class QuestionDiscussion extends Equatable {
  const QuestionDiscussion({
    required this.id,
    required this.questionId,
    required this.content,
    required this.author,
    this.parentId,
    this.authorRole = 'student',
    this.isEdited = false,
    this.isOwner = false,
    this.likeCount = 0,
    this.dislikeCount = 0,
    this.myReaction,
    this.createdAt,
    this.replies = const [],
  });

  final String id;
  final String questionId;
  final String? parentId;
  final String content;

  /// `student | teacher | admin` — drives the badge beside the name.
  final String authorRole;

  final bool isEdited;

  /// The server decides this, not the client comparing ids — a discussion is
  /// visible to teachers and admins too, and they own different posts.
  final bool isOwner;

  final int likeCount;
  final int dislikeCount;

  /// `like`, `dislike`, or null when this user has not reacted.
  final String? myReaction;

  final DiscussionAuthor author;
  final String? createdAt;
  final List<QuestionDiscussion> replies;

  bool get isReply => parentId != null;
  bool get isTeacher => authorRole == 'teacher' || authorRole == 'admin';

  /// The same post with its reaction counts replaced — what an optimistic tap
  /// emits before the server has agreed.
  QuestionDiscussion withReaction({
    required int likeCount,
    required int dislikeCount,
    required String? myReaction,
  }) =>
      QuestionDiscussion(
        id: id,
        questionId: questionId,
        content: content,
        author: author,
        parentId: parentId,
        authorRole: authorRole,
        isEdited: isEdited,
        isOwner: isOwner,
        likeCount: likeCount,
        dislikeCount: dislikeCount,
        myReaction: myReaction,
        createdAt: createdAt,
        replies: replies,
      );

  @override
  List<Object?> get props => [
        id,
        content,
        isEdited,
        likeCount,
        dislikeCount,
        myReaction,
        replies,
      ];
}

class DiscussionAuthor extends Equatable {
  const DiscussionAuthor({required this.id, this.fullName, this.avatar});

  final String id;
  final String? fullName;
  final String? avatar;

  String get displayName =>
      (fullName ?? '').trim().isEmpty ? 'Unknown' : fullName!.trim();

  @override
  List<Object?> get props => [id, fullName, avatar];
}

/// `GET /practice/questions/:id/discussions`.
class DiscussionThread extends Equatable {
  const DiscussionThread({this.discussions = const [], this.canModerate = false});

  final List<QuestionDiscussion> discussions;

  /// True for a teacher or admin, who may edit or delete anyone's post.
  final bool canModerate;

  @override
  List<Object?> get props => [discussions, canModerate];
}

/// What a reaction call answers with — the new counts, not the whole post.
class DiscussionReactionCounts extends Equatable {
  const DiscussionReactionCounts({
    required this.likeCount,
    required this.dislikeCount,
    this.myReaction,
  });

  final int likeCount;
  final int dislikeCount;
  final String? myReaction;

  @override
  List<Object?> get props => [likeCount, dislikeCount, myReaction];
}
