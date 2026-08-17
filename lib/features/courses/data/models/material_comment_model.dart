import '../../domain/entities/material_comment.dart';

/// JSON → [MaterialComment], the payload of the material comment endpoints.
class MaterialCommentModel extends MaterialComment {
  const MaterialCommentModel({
    required super.id,
    required super.courseMaterialId,
    required super.content,
    required super.authorRole,
    required super.isEdited,
    required super.author,
    super.parentCommentId,
    super.createdAt,
    super.updatedAt,
    super.replies,
  });

  factory MaterialCommentModel.fromJson(Map<String, dynamic> json) =>
      MaterialCommentModel(
        id: json['id'] as String? ?? '',
        courseMaterialId: json['courseMaterialId'] as String? ?? '',
        parentCommentId: json['parentCommentId'] as String?,
        content: json['content'] as String? ?? '',
        authorRole: json['authorRole'] as String? ?? 'student',
        isEdited: json['isEdited'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
        author: _author(json['author']),
        // Only top-level comments carry replies, and only one level deep.
        replies: (json['replies'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(MaterialCommentModel.fromJson)
                .toList(growable: false) ??
            const [],
      );

  static CommentAuthor _author(Object? value) {
    final json = value is Map<String, dynamic> ? value : const <String, dynamic>{};
    return CommentAuthor(
      id: json['id'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      avatar: json['avatar'] as String?,
    );
  }
}
