import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/material_comment.dart';
import '../repositories/course_repository.dart';

/// The comment thread on a material, top-level comments with replies nested.
class ListMaterialCommentsUseCase
    implements UseCase<List<MaterialComment>, IdParams> {
  const ListMaterialCommentsUseCase(this._repository);

  final CourseRepository _repository;

  @override
  Future<Either<Failure, List<MaterialComment>>> call(IdParams params) =>
      _repository.listComments(params.id);
}

class CreateMaterialCommentUseCase
    implements UseCase<MaterialComment, CommentParams> {
  const CreateMaterialCommentUseCase(this._repository);

  final CourseRepository _repository;

  @override
  Future<Either<Failure, MaterialComment>> call(CommentParams params) =>
      _repository.createComment(
        materialId: params.targetId,
        content: params.content,
      );
}

/// Replies to a top-level comment. The backend rejects a deeper thread with
/// `COURSE_COMMENT_REPLY_DEPTH`, so callers must never pass a reply's id.
class ReplyToMaterialCommentUseCase
    implements UseCase<MaterialComment, CommentParams> {
  const ReplyToMaterialCommentUseCase(this._repository);

  final CourseRepository _repository;

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

  final CourseRepository _repository;

  @override
  Future<Either<Failure, MaterialComment>> call(CommentParams params) =>
      _repository.updateComment(
        commentId: params.targetId,
        content: params.content,
      );
}

class DeleteMaterialCommentUseCase implements UseCase<Unit, IdParams> {
  const DeleteMaterialCommentUseCase(this._repository);

  final CourseRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(IdParams params) =>
      _repository.deleteComment(params.id);
}

/// [targetId] is the material for a new comment and the comment for a reply or
/// an edit — the three calls differ only in what the id points at.
class CommentParams extends Equatable {
  const CommentParams({required this.targetId, required this.content});

  final String targetId;
  final String content;

  @override
  List<Object?> get props => [targetId, content];
}
