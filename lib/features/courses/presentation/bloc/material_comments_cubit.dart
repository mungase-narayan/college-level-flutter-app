import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/common/bloc/remote_cubit.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/material_comment.dart';
import '../../domain/usecases/material_comment_usecases.dart';

/// The comment thread on one material — the port of `CommentsSection`'s
/// react-query hooks.
///
/// Every mutation reloads the thread rather than patching it locally: the
/// server owns `isEdited`, the reply ordering, and the author block, and the
/// list is small enough that a refetch is cheaper than keeping a second copy
/// of those rules here.
class MaterialCommentsCubit extends Cubit<RemoteState<List<MaterialComment>>> {
  MaterialCommentsCubit({
    required ListMaterialCommentsUseCase list,
    required CreateMaterialCommentUseCase create,
    required ReplyToMaterialCommentUseCase reply,
    required UpdateMaterialCommentUseCase update,
    required DeleteMaterialCommentUseCase remove,
    required this.materialId,
  })  : _list = list,
        _create = create,
        _reply = reply,
        _update = update,
        _remove = remove,
        super(const RemoteState());

  final ListMaterialCommentsUseCase _list;
  final CreateMaterialCommentUseCase _create;
  final ReplyToMaterialCommentUseCase _reply;
  final UpdateMaterialCommentUseCase _update;
  final DeleteMaterialCommentUseCase _remove;
  final String materialId;

  bool _submitting = false;

  /// True while a post/reply/edit/delete is in flight, so the composer can
  /// disable itself rather than allowing a double submit.
  bool get isSubmitting => _submitting;

  Future<void> load({bool refresh = false}) async {
    if (isClosed) return;
    emit(state.copyWith(
      status: RemoteStatus.loading,
      isRefreshing: refresh,
      clearFailure: true,
    ));

    final result = await _list(IdParams(materialId));
    if (isClosed) return;

    result.fold(
      (failure) => emit(state.copyWith(
        status: RemoteStatus.failure,
        failure: failure,
        isRefreshing: false,
      )),
      (items) => emit(RemoteState(status: RemoteStatus.success, data: items)),
    );
  }

  Future<Failure?> post(String content) => _mutate(
        () => _create(CommentParams(targetId: materialId, content: content)),
      );

  Future<Failure?> replyTo(String commentId, String content) => _mutate(
        () => _reply(CommentParams(targetId: commentId, content: content)),
      );

  Future<Failure?> edit(String commentId, String content) => _mutate(
        () => _update(CommentParams(targetId: commentId, content: content)),
      );

  Future<Failure?> delete(String commentId) =>
      _mutate(() => _remove(IdParams(commentId)));

  /// Runs a mutation, then reloads. Returns the failure so the caller can toast
  /// it — a 403 `COURSE_COMMENT_NO_DIVISION` is the one students actually hit.
  Future<Failure?> _mutate(
    Future<Either<Failure, Object?>> Function() action,
  ) async {
    if (_submitting) return null;
    _submitting = true;

    final result = await action();

    _submitting = false;
    if (isClosed) return null;

    final failure = result.fold((f) => f, (_) => null);
    if (failure == null) await load(refresh: true);
    return failure;
  }
}
