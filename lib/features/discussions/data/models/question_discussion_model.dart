import '../../domain/entities/question_discussion.dart';

int _int(Object? value) => (value as num?)?.toInt() ?? 0;
Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const {};
List<Map<String, dynamic>> _maps(Object? value) =>
    (value as List?)?.whereType<Map<String, dynamic>>().toList(growable: false) ??
    const [];

class QuestionDiscussionModel extends QuestionDiscussion {
  const QuestionDiscussionModel({
    required super.id,
    required super.questionId,
    required super.content,
    required super.author,
    super.parentId,
    super.authorRole,
    super.isEdited,
    super.isOwner,
    super.likeCount,
    super.dislikeCount,
    super.myReaction,
    super.createdAt,
    super.replies,
  });

  factory QuestionDiscussionModel.fromJson(Map<String, dynamic> json) =>
      QuestionDiscussionModel(
        id: json['id'] as String? ?? '',
        questionId: json['questionId'] as String? ?? '',
        content: json['content'] as String? ?? '',
        author: _author(_map(json['author'])),
        parentId: json['parentId'] as String?,
        authorRole: json['authorRole'] as String? ?? 'student',
        isEdited: json['isEdited'] as bool? ?? false,
        // Ownership is the server's call: a teacher reading a student's thread
        // owns none of it, and a moderator may edit posts they do not own.
        isOwner: json['isOwner'] as bool? ?? false,
        likeCount: _int(json['likeCount']),
        dislikeCount: _int(json['dislikeCount']),
        myReaction: json['myReaction'] as String?,
        createdAt: json['createdAt'] as String?,
        replies: _maps(json['replies'])
            .map(QuestionDiscussionModel.fromJson)
            .toList(growable: false),
      );

  static DiscussionAuthor _author(Map<String, dynamic> json) => DiscussionAuthor(
        id: json['id'] as String? ?? '',
        fullName: json['fullName'] as String?,
        avatar: json['avatar'] as String?,
      );
}

DiscussionThread threadFromJson(Map<String, dynamic> json) => DiscussionThread(
      discussions: _maps(json['discussions'])
          .map(QuestionDiscussionModel.fromJson)
          .toList(growable: false),
      canModerate: json['canModerate'] as bool? ?? false,
    );

DiscussionReactionCounts reactionFromJson(Map<String, dynamic> json) =>
    DiscussionReactionCounts(
      likeCount: _int(json['likeCount']),
      dislikeCount: _int(json['dislikeCount']),
      myReaction: json['myReaction'] as String?,
    );
