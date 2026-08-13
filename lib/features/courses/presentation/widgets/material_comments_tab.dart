import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/presentation/bloc/auth/auth_bloc.dart';
import '../../domain/entities/material_comment.dart';
import '../bloc/material_comments_cubit.dart';

/// Port of `CommentsSection` for a course material.
///
/// A one-level thread: top-level comments each with their replies. Bodies are
/// rendered through [AppMarkdown], so a comment picks up the same rich blocks
/// the material content does — exactly as on the web, where both go through the
/// shared `Markdown`.
class MaterialCommentsTab extends StatefulWidget {
  const MaterialCommentsTab({super.key});

  @override
  State<MaterialCommentsTab> createState() => _MaterialCommentsTabState();
}

class _MaterialCommentsTabState extends State<MaterialCommentsTab> {
  final _controller = TextEditingController();

  /// The comment being replied to, or null when composing a new top-level one.
  String? _replyTo;

  @override
  void initState() {
    super.initState();
    context.read<MaterialCommentsCubit>().load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;

    final cubit = context.read<MaterialCommentsCubit>();
    final target = _replyTo;
    final failure = target == null
        ? await cubit.post(content)
        : await cubit.replyTo(target, content);

    if (!mounted) return;
    if (failure != null) {
      _report(failure);
      return;
    }
    _controller.clear();
    setState(() => _replyTo = null);
  }

  /// A student with no division cannot comment at all — the backend returns
  /// `COURSE_COMMENT_NO_DIVISION` because threads are scoped per division.
  void _report(Failure failure) {
    final message = failure is ForbiddenFailure
        ? 'Comments are only open to students assigned to a division.'
        : failure.message;
    AppToast.error(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MaterialCommentsCubit>();
    final currentUserId = context.select<AuthBloc, String?>(
      (bloc) => bloc.state.user?.id,
    );

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => cubit.load(refresh: true),
            child: RemoteView<MaterialCommentsCubit, List<MaterialComment>>(
              onRetry: cubit.load,
              loading: const Padding(
                padding: EdgeInsets.all(16),
                child: AppListSkeleton(rows: 2),
              ),
              builder: (context, comments) {
                if (comments.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 40),
                      AppEmptyState(
                        title: 'No comments yet',
                        description:
                            'Start the discussion on this material.',
                        icon: Icons.forum_outlined,
                      ),
                    ],
                  );
                }

                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  itemCount: comments.length,
                  itemBuilder: (context, index) => _CommentThread(
                    comment: comments[index],
                    currentUserId: currentUserId,
                    onReply: (id) => setState(() => _replyTo = id),
                    onReport: _report,
                  ),
                );
              },
            ),
          ),
        ),
        _Composer(
          controller: _controller,
          replyingTo: _replyTo == null
              ? null
              : _findAuthor(cubit.state.data, _replyTo!),
          onCancelReply: () => setState(() => _replyTo = null),
          onSubmit: _submit,
        ),
      ],
    );
  }

  String? _findAuthor(List<MaterialComment>? comments, String id) {
    for (final comment in comments ?? const <MaterialComment>[]) {
      if (comment.id == id) return comment.author.displayName;
    }
    return null;
  }
}

/// A top-level comment with its replies indented beneath it.
class _CommentThread extends StatelessWidget {
  const _CommentThread({
    required this.comment,
    required this.currentUserId,
    required this.onReply,
    required this.onReport,
  });

  final MaterialComment comment;
  final String? currentUserId;
  final ValueChanged<String> onReply;
  final void Function(Failure failure) onReport;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CommentRow(
            comment: comment,
            currentUserId: currentUserId,
            // Only a top-level comment can be replied to; the backend rejects a
            // deeper thread with COURSE_COMMENT_REPLY_DEPTH.
            onReply: () => onReply(comment.id),
            onReport: onReport,
          ),
          if (comment.replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 8),
              child: Container(
                padding: const EdgeInsets.only(left: 12),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: scheme.border, width: 1.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final reply in comment.replies)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _CommentRow(
                          comment: reply,
                          currentUserId: currentUserId,
                          onReply: null,
                          onReport: onReport,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CommentRow extends StatefulWidget {
  const _CommentRow({
    required this.comment,
    required this.currentUserId,
    required this.onReply,
    required this.onReport,
  });

  final MaterialComment comment;
  final String? currentUserId;

  /// Null on a reply — replies cannot be replied to.
  final VoidCallback? onReply;
  final void Function(Failure failure) onReport;

  @override
  State<_CommentRow> createState() => _CommentRowState();
}

class _CommentRowState extends State<_CommentRow> {
  TextEditingController? _editor;

  bool get _editing => _editor != null;

  @override
  void dispose() {
    _editor?.dispose();
    super.dispose();
  }

  void _startEdit() {
    setState(
      () => _editor = TextEditingController(text: widget.comment.content),
    );
  }

  void _cancelEdit() {
    _editor?.dispose();
    setState(() => _editor = null);
  }

  Future<void> _saveEdit() async {
    final content = _editor?.text.trim() ?? '';
    if (content.isEmpty) return;

    final failure = await context
        .read<MaterialCommentsCubit>()
        .edit(widget.comment.id, content);
    if (!mounted) return;
    if (failure != null) {
      widget.onReport(failure);
      return;
    }
    _cancelEdit();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final failure =
        await context.read<MaterialCommentsCubit>().delete(widget.comment.id);
    if (mounted && failure != null) widget.onReport(failure);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final comment = widget.comment;
    final isOwner = comment.isOwnedBy(widget.currentUserId);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppAvatar(
          imageUrl: comment.author.avatar,
          name: comment.author.displayName,
          size: 32,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 2,
                children: [
                  Text(
                    comment.author.displayName,
                    style: theme.textTheme.labelMedium,
                  ),
                  if (comment.isTeacher)
                    AppBadge(
                      'Teacher',
                      shade: TwColors.violet,
                      dense: true,
                    ),
                  Text(
                    Fmt.relative(comment.createdAt?.toIso8601String()),
                    style: theme.textTheme.labelSmall,
                  ),
                  if (comment.isEdited)
                    Text('(edited)', style: theme.textTheme.labelSmall),
                ],
              ),
              const SizedBox(height: 4),
              if (_editing) ...[
                TextField(
                  controller: _editor,
                  maxLines: null,
                  maxLength: 5000,
                  decoration: const InputDecoration(isDense: true),
                ),
                Row(
                  children: [
                    AppButton(
                      label: 'Save',
                      size: AppButtonSize.sm,
                      onPressed: _saveEdit,
                    ),
                    const SizedBox(width: 8),
                    AppButton(
                      label: 'Cancel',
                      size: AppButtonSize.sm,
                      variant: AppButtonVariant.ghost,
                      onPressed: _cancelEdit,
                    ),
                  ],
                ),
              ] else
                AppMarkdown(comment.content, selectable: false),
              const SizedBox(height: 2),
              if (!_editing)
                Row(
                  children: [
                    if (widget.onReply != null)
                      _Action(label: 'Reply', onTap: widget.onReply!),
                    if (isOwner) ...[
                      _Action(label: 'Edit', onTap: _startEdit),
                      _Action(
                        label: 'Delete',
                        onTap: _delete,
                        color: scheme.destructive,
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.label, required this.onTap, this.color});

  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color ?? scheme.mutedForeground,
          ),
        ),
      ),
    );
  }
}

/// The pinned composer at the foot of the tab.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.replyingTo,
    required this.onCancelReply,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String? replyingTo;
  final VoidCallback onCancelReply;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: BoxDecoration(
        color: scheme.card,
        border: Border(top: BorderSide(color: scheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyingTo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Replying to $replyingTo',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                  InkWell(
                    onTap: onCancelReply,
                    child: Icon(
                      Icons.close_rounded,
                      size: 15,
                      color: scheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  // The validator caps a comment at 5000 characters.
                  maxLength: 5000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Write a comment…',
                    isDense: true,
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: onSubmit,
                icon: const Icon(Icons.send_rounded, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
