import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../../../../core/error/failures.dart';
import '../../../../../core/usecases/usecase.dart';
import '../../domain/entities/question_discussion.dart';
import '../../domain/usecases/discussion_usecases.dart';

/// The discussion thread on one practice question.
class DiscussionCubit extends Cubit<RemoteState<DiscussionThread>> {
  DiscussionCubit({
    required ListDiscussionsUseCase list,
    required PostDiscussionUseCase post,
    required EditDiscussionUseCase edit,
    required DeleteDiscussionUseCase remove,
    required ReactToDiscussionUseCase react,
    required this.questionId,
  })  : _list = list,
        _post = post,
        _edit = edit,
        _remove = remove,
        _react = react,
        super(const RemoteState());

  final ListDiscussionsUseCase _list;
  final PostDiscussionUseCase _post;
  final EditDiscussionUseCase _edit;
  final DeleteDiscussionUseCase _remove;
  final ReactToDiscussionUseCase _react;

  final String questionId;

  bool _isPosting = false;
  bool get isPosting => _isPosting;

  Future<void> load({bool refresh = false}) async {
    if (isClosed) return;
    emit(state.copyWith(
      status: RemoteStatus.loading,
      isRefreshing: refresh,
      clearFailure: true,
    ));

    final result = await _list(IdParams(questionId));
    if (isClosed) return;

    result.fold(
      (failure) => emit(state.copyWith(
        status: RemoteStatus.failure,
        failure: failure,
        isRefreshing: false,
      )),
      (thread) => emit(RemoteState(status: RemoteStatus.success, data: thread)),
    );
  }

  /// Posts a new thread, or a reply when [parentId] is given.
  ///
  /// Reloads rather than splicing the response in: a reply changes its parent's
  /// nesting, and the server is the one that knows the resulting order.
  Future<Failure?> post(String content, {String? parentId}) async {
    if (isClosed || _isPosting) return null;
    _isPosting = true;

    final result = await _post(
      DiscussionPost(
        questionId: questionId,
        content: content,
        parentId: parentId,
      ),
    );
    _isPosting = false;
    if (isClosed) return null;

    return await result.fold(
      (failure) async => failure,
      (_) async {
        await load(refresh: true);
        return null;
      },
    );
  }

  Future<Failure?> edit(String discussionId, String content) async {
    if (isClosed) return null;

    final result = await _edit(
      DiscussionEdit(discussionId: discussionId, content: content),
    );
    if (isClosed) return null;

    return await result.fold(
      (failure) async => failure,
      (_) async {
        await load(refresh: true);
        return null;
      },
    );
  }

  Future<Failure?> delete(String discussionId) async {
    if (isClosed) return null;

    final result = await _remove(IdParams(discussionId));
    if (isClosed) return null;

    return await result.fold(
      (failure) async => failure,
      (_) async {
        await load(refresh: true);
        return null;
      },
    );
  }

  /// Likes or dislikes a post, updating the counts in place.
  ///
  /// Optimism would be wrong here: the toggle lives on the server (sending the
  /// same reaction twice clears it), so the true counts only arrive with the
  /// response. The round trip is one small request and the row updates alone.
  Future<Failure?> react(String discussionId, String type) async {
    final current = state.data;
    if (isClosed || current == null) return null;

    final result = await _react(
      DiscussionReaction(discussionId: discussionId, type: type),
    );
    if (isClosed) return null;

    return result.fold(
      (failure) => failure,
      (counts) {
        emit(state.copyWith(
          data: DiscussionThread(
            canModerate: current.canModerate,
            discussions: _applyReaction(current.discussions, discussionId, counts),
          ),
        ));
        return null;
      },
    );
  }

  /// Replaces the reacted-to post wherever it sits — top level or one reply
  /// down — leaving the rest of the thread untouched.
  List<QuestionDiscussion> _applyReaction(
    List<QuestionDiscussion> posts,
    String discussionId,
    DiscussionReactionCounts counts,
  ) =>
      [
        for (final post in posts)
          if (post.id == discussionId)
            post.withReaction(
              likeCount: counts.likeCount,
              dislikeCount: counts.dislikeCount,
              myReaction: counts.myReaction,
            )
          else if (post.replies.any((reply) => reply.id == discussionId))
            _withReplies(
              post,
              _applyReaction(post.replies, discussionId, counts),
            )
          else
            post,
      ];

  QuestionDiscussion _withReplies(
    QuestionDiscussion post,
    List<QuestionDiscussion> replies,
  ) =>
      QuestionDiscussion(
        id: post.id,
        questionId: post.questionId,
        content: post.content,
        author: post.author,
        parentId: post.parentId,
        authorRole: post.authorRole,
        isEdited: post.isEdited,
        isOwner: post.isOwner,
        likeCount: post.likeCount,
        dislikeCount: post.dislikeCount,
        myReaction: post.myReaction,
        createdAt: post.createdAt,
        replies: replies,
      );
}
