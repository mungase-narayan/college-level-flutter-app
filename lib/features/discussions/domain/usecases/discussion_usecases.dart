import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/question_discussion.dart';
import '../repositories/discussion_repository.dart';

/// The thread on a question, plus whether this user may moderate it.
class ListDiscussionsUseCase implements UseCase<DiscussionThread, IdParams> {
  const ListDiscussionsUseCase(this._repository);

  final DiscussionRepository _repository;

  @override
  Future<Either<Failure, DiscussionThread>> call(IdParams params) =>
      _repository.list(params.id);
}

/// Starts a new thread, or answers an existing one when [DiscussionPost.parentId]
/// is set — the two are different endpoints, chosen here rather than by the UI.
class PostDiscussionUseCase
    implements UseCase<QuestionDiscussion, DiscussionPost> {
  const PostDiscussionUseCase(this._repository);

  final DiscussionRepository _repository;

  @override
  Future<Either<Failure, QuestionDiscussion>> call(DiscussionPost params) {
    final parentId = params.parentId;
    return parentId == null
        ? _repository.create(
            questionId: params.questionId,
            content: params.content,
          )
        : _repository.reply(discussionId: parentId, content: params.content);
  }
}

class DiscussionPost extends Equatable {
  const DiscussionPost({
    required this.questionId,
    required this.content,
    this.parentId,
  });

  final String questionId;
  final String content;

  /// Set to answer a post rather than start one. Threads are one level deep,
  /// so this is always a top-level post's id.
  final String? parentId;

  @override
  List<Object?> get props => [questionId, content, parentId];
}

class EditDiscussionUseCase
    implements UseCase<QuestionDiscussion, DiscussionEdit> {
  const EditDiscussionUseCase(this._repository);

  final DiscussionRepository _repository;

  @override
  Future<Either<Failure, QuestionDiscussion>> call(DiscussionEdit params) =>
      _repository.update(
        discussionId: params.discussionId,
        content: params.content,
      );
}

class DiscussionEdit extends Equatable {
  const DiscussionEdit({required this.discussionId, required this.content});

  final String discussionId;
  final String content;

  @override
  List<Object?> get props => [discussionId, content];
}

class DeleteDiscussionUseCase implements UseCase<Unit, IdParams> {
  const DeleteDiscussionUseCase(this._repository);

  final DiscussionRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(IdParams params) =>
      _repository.remove(params.id);
}

/// Likes or dislikes a post. Sending the same reaction again clears it.
class ReactToDiscussionUseCase
    implements UseCase<DiscussionReactionCounts, DiscussionReaction> {
  const ReactToDiscussionUseCase(this._repository);

  final DiscussionRepository _repository;

  @override
  Future<Either<Failure, DiscussionReactionCounts>> call(
    DiscussionReaction params,
  ) =>
      _repository.react(
        discussionId: params.discussionId,
        type: params.type,
      );
}

class DiscussionReaction extends Equatable {
  const DiscussionReaction({required this.discussionId, required this.type});

  final String discussionId;

  /// `like` or `dislike`.
  final String type;

  @override
  List<Object?> get props => [discussionId, type];
}
