import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/error/guard.dart';
import '../../domain/entities/question_discussion.dart';
import '../../domain/repositories/discussion_repository.dart';
import '../datasources/discussion_service.dart';

class DiscussionRepositoryImpl
    with RepositoryGuard
    implements DiscussionRepository {
  const DiscussionRepositoryImpl(this._service);

  final DiscussionService _service;

  @override
  Future<Either<Failure, DiscussionThread>> list(String questionId) =>
      guard(() => _service.list(questionId));

  @override
  Future<Either<Failure, QuestionDiscussion>> create({
    required String questionId,
    required String content,
  }) =>
      guard(() => _service.create(questionId: questionId, content: content));

  @override
  Future<Either<Failure, QuestionDiscussion>> reply({
    required String discussionId,
    required String content,
  }) =>
      guard(() => _service.reply(discussionId: discussionId, content: content));

  @override
  Future<Either<Failure, QuestionDiscussion>> update({
    required String discussionId,
    required String content,
  }) =>
      guard(() => _service.update(discussionId: discussionId, content: content));

  @override
  Future<Either<Failure, Unit>> remove(String discussionId) => guard(() async {
        await _service.remove(discussionId);
        return unit;
      });

  @override
  Future<Either<Failure, DiscussionReactionCounts>> react({
    required String discussionId,
    required String type,
  }) =>
      guard(() => _service.react(discussionId: discussionId, type: type));
}
