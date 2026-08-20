import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../entities/question_discussion.dart';

abstract class DiscussionRepository {
  Future<Either<Failure, DiscussionThread>> list(String questionId);

  Future<Either<Failure, QuestionDiscussion>> create({
    required String questionId,
    required String content,
  });

  Future<Either<Failure, QuestionDiscussion>> reply({
    required String discussionId,
    required String content,
  });

  Future<Either<Failure, QuestionDiscussion>> update({
    required String discussionId,
    required String content,
  });

  Future<Either<Failure, Unit>> remove(String discussionId);

  /// Posting the same reaction twice clears it — the toggle is server-side.
  Future<Either<Failure, DiscussionReactionCounts>> react({
    required String discussionId,
    required String type,
  });
}
