import '../../../../core/constants/api_urls.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/entities/question_discussion.dart';
import '../models/question_discussion_model.dart';

/// Raw HTTP for question discussions — the port of
/// `src/api/question-discussions`.
///
/// These routes sit under `/practice`, not `/student`: a discussion is visible
/// to any signed-in role, which is what lets a teacher answer in the thread.
class DiscussionService {
  const DiscussionService(this._client);

  final DioClient _client;

  Future<DiscussionThread> list(String questionId) async {
    final response = await _client.get(
      ApiUrls.questionDiscussions(questionId),
      parse: (data) => threadFromJson((data as Map<String, dynamic>?) ?? const {}),
    );
    return response.data;
  }

  Future<QuestionDiscussionModel> create({
    required String questionId,
    required String content,
  }) async {
    final response = await _client.post(
      ApiUrls.questionDiscussions(questionId),
      body: {'content': content},
      parse: (data) => QuestionDiscussionModel.fromJson(
        (data as Map<String, dynamic>?) ?? const {},
      ),
    );
    return response.data;
  }

  Future<QuestionDiscussionModel> reply({
    required String discussionId,
    required String content,
  }) async {
    final response = await _client.post(
      ApiUrls.discussionReplies(discussionId),
      body: {'content': content},
      parse: (data) => QuestionDiscussionModel.fromJson(
        (data as Map<String, dynamic>?) ?? const {},
      ),
    );
    return response.data;
  }

  Future<QuestionDiscussionModel> update({
    required String discussionId,
    required String content,
  }) async {
    final response = await _client.patch(
      ApiUrls.discussion(discussionId),
      body: {'content': content},
      parse: (data) => QuestionDiscussionModel.fromJson(
        (data as Map<String, dynamic>?) ?? const {},
      ),
    );
    return response.data;
  }

  Future<void> remove(String discussionId) async {
    await _client.delete(ApiUrls.discussion(discussionId), parse: (_) => null);
  }

  /// Toggling is server-side: posting the same reaction twice clears it, and
  /// the response is the new counts rather than the whole post.
  Future<DiscussionReactionCounts> react({
    required String discussionId,
    required String type,
  }) async {
    final response = await _client.post(
      ApiUrls.discussionReactions(discussionId),
      body: {'type': type},
      parse: (data) =>
          reactionFromJson((data as Map<String, dynamic>?) ?? const {}),
    );
    return response.data;
  }
}
