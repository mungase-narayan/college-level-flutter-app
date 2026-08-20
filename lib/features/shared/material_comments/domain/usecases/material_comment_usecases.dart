import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecases/usecase.dart';
import '../entities/material_comment.dart';
import '../repositories/material_comment_source.dart';

/// The comment thread on a material, top-level comments with replies nested.
class ListMaterialCommentsUseCase
    implements UseCase<List<MaterialComment>, CommentThreadParams> {
  const ListMaterialCommentsUseCase(this._repository);

  final MaterialCommentSource _repository;

  @override
  Future<Either<Failure, List<MaterialComment>>> call(
    CommentThreadParams params,
  ) =>
      _repository.listComments(
        params.materialId,
        divisionId: params.divisionId,
      );
}

class CreateMaterialCommentUseCase
    implements UseCase<MaterialComment, CommentParams> {
  const CreateMaterialCommentUseCase(this._repository);

  final MaterialCommentSource _repository;

  @override
  Future<Either<Failure, MaterialComment>> call(CommentParams params) =>
      _repository.createComment(
        materialId: params.targetId,
        content: params.content,
        divisionId: params.divisionId,
      );
}

/// Replies to a top-level comment. The backend rejects a deeper thread with
/// `COURSE_COMMENT_REPLY_DEPTH`, so callers must never pass a reply's id.
class ReplyToMaterialCommentUseCase
    implements UseCase<MaterialComment, CommentParams> {
  const ReplyToMaterialCommentUseCase(this._repository);

  final MaterialCommentSource _repository;

  @override
  Future<Either<Failure, MaterialComment>> call(CommentParams params) =>
      _repository.replyToComment(
        commentId: params.targetId,
        content: params.content,
      );
}

class UpdateMaterialCommentUseCase
    implements UseCase<MaterialComment, CommentParams> {
  const UpdateMaterialCommentUseCase(this._repository);

  final MaterialCommentSource _repository;

  @override
  Future<Either<Failure, MaterialComment>> call(CommentParams params) =>
      _repository.updateComment(
        commentId: params.targetId,
        content: params.content,
      );
}

class DeleteMaterialCommentUseCase implements UseCase<Unit, IdParams> {
  const DeleteMaterialCommentUseCase(this._repository);

  final MaterialCommentSource _repository;

  @override
  Future<Either<Failure, Unit>> call(IdParams params) =>
      _repository.deleteComment(params.id);
}

/// [targetId] is the material for a new comment and the comment for a reply or
/// an edit — the three calls differ only in what the id points at.
class CommentParams extends Equatable {
  const CommentParams({
    required this.targetId,
    required this.content,
    this.divisionId,
  });

  final String targetId;
  final String content;

  /// Required when posting as a teacher, ignored as a student — see
  /// [MaterialCommentSource].
  final String? divisionId;

  @override
  List<Object?> get props => [targetId, content, divisionId];
}

/// Which thread to read: the material, and for a teacher the section.
class CommentThreadParams extends Equatable {
  const CommentThreadParams({required this.materialId, this.divisionId});

  final String materialId;
  final String? divisionId;

  @override
  List<Object?> get props => [materialId, divisionId];
}
