import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_colors.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/design/extensions/glass_context.dart';
import '../../../../../core/design/theme/glass_specs.dart';
import '../../../../../core/design/widgets/liquid_glass_container.dart';
import '../../../../../core/error/failures.dart';
import '../../../../../core/utils/formatters.dart';
import '../../domain/entities/question_discussion.dart';
import '../bloc/discussion_cubit.dart';

/// The discussion thread on a practice question.
///
/// Deliberately the same shape as the course-material comments: avatar, name,
/// body, a quiet meta line, replies collapsed behind a count, and owner actions
/// behind a long press. The one thing comments do not have is reactions.
class DiscussionTab extends StatefulWidget {
  const DiscussionTab({super.key});

  @override
  State<DiscussionTab> createState() => _DiscussionTabState();
}

class _DiscussionTabState extends State<DiscussionTab> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  /// The post being answered, or null when starting a new thread.
  String? _replyTo;
  String? _replyToName;

  @override
  void initState() {
    super.initState();
    context.read<DiscussionCubit>().load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _report(Failure failure) => AppToast.failure(context, failure);

  Future<void> _send() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;

    final failure =
        await context.read<DiscussionCubit>().post(content, parentId: _replyTo);
    if (!mounted) return;

    if (failure != null) {
      _report(failure);
      return;
    }
    _controller.clear();
    setState(() {
      _replyTo = null;
      _replyToName = null;
    });
  }

  void _startReply(QuestionDiscussion post) {
    setState(() {
      _replyTo = post.id;
      _replyToName = post.author.displayName;
    });
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DiscussionCubit>();

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => cubit.load(refresh: true),
            child: RemoteView<DiscussionCubit, DiscussionThread>(
              onRetry: cubit.load,
              loading: const Padding(
                padding: EdgeInsets.all(16),
                child: AppListSkeleton(rows: 2),
              ),
              builder: (context, thread) {
                if (thread.discussions.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 40),
                      AppEmptyState(
                        title: 'No discussion yet',
                        description:
                            'Ask about this question, or explain how you '
                            'approached it.',
                        icon: Icons.forum_outlined,
                      ),
                    ],
                  );
                }

                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: thread.discussions.length,
                  itemBuilder: (context, index) => _DiscussionThreadTile(
                    post: thread.discussions[index],
                    canModerate: thread.canModerate,
                    onReply: _startReply,
                    onReport: _report,
                  ),
                );
              },
            ),
          ),
        ),
        _Composer(
          controller: _controller,
          focusNode: _focus,
          replyingTo: _replyToName,
          onCancelReply: () => setState(() {
            _replyTo = null;
            _replyToName = null;
          }),
          onSend: _send,
        ),
      ],
    );
  }
}

/// A top-level post with its replies collapsed beneath it.
class _DiscussionThreadTile extends StatefulWidget {
  const _DiscussionThreadTile({
    required this.post,
    required this.canModerate,
    required this.onReply,
    required this.onReport,
  });

  final QuestionDiscussion post;
  final bool canModerate;
  final ValueChanged<QuestionDiscussion> onReply;
  final void Function(Failure failure) onReport;

  @override
  State<_DiscussionThreadTile> createState() => _DiscussionThreadTileState();
}

class _DiscussionThreadTileState extends State<_DiscussionThreadTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final replies = widget.post.replies;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DiscussionRow(
            post: widget.post,
            canModerate: widget.canModerate,
            onReply: () => widget.onReply(widget.post),
            onReport: widget.onReport,
          ),
          if (replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 46, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 22, height: 1, color: scheme.border),
                          const SizedBox(width: 10),
                          Text(
                            _expanded
                                ? 'Hide replies'
                                : 'View ${replies.length == 1 ? '1 reply' : '${replies.length} replies'}',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: scheme.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_expanded)
                    for (final reply in replies)
                      _DiscussionRow(
                        post: reply,
                        canModerate: widget.canModerate,
                        onReply: null,
                        onReport: widget.onReport,
                      ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DiscussionRow extends StatefulWidget {
  const _DiscussionRow({
    required this.post,
    required this.canModerate,
    required this.onReply,
    required this.onReport,
  });

  final QuestionDiscussion post;
  final bool canModerate;

  /// Null on a reply — threads are one level deep.
  final VoidCallback? onReply;
  final void Function(Failure failure) onReport;

  @override
  State<_DiscussionRow> createState() => _DiscussionRowState();
}

class _DiscussionRowState extends State<_DiscussionRow> {
  TextEditingController? _editor;

  bool get _editing => _editor != null;

  @override
  void dispose() {
    _editor?.dispose();
    super.dispose();
  }

  Future<void> _openActions() async {
    final post = widget.post;
    final mayChange = post.isOwner || widget.canModerate;

    final action = await showAppOptionSheet<String>(
      context,
      title: post.author.displayName,
      options: [
        if (widget.onReply != null)
          const AppSheetOption(
            value: 'reply',
            label: 'Reply',
            icon: Icons.reply_rounded,
          ),
        if (mayChange) ...[
          const AppSheetOption(
            value: 'edit',
            label: 'Edit',
            icon: Icons.edit_outlined,
          ),
          const AppSheetOption(
            value: 'delete',
            label: 'Delete',
            icon: Icons.delete_outline_rounded,
            destructive: true,
          ),
        ],
      ],
    );
    if (action == null || !mounted) return;

    switch (action) {
      case 'reply':
        widget.onReply?.call();
      case 'edit':
        setState(() => _editor = TextEditingController(text: post.content));
      case 'delete':
        await _delete();
    }
  }

  Future<void> _delete() async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete post?',
      message: 'This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    final failure =
        await context.read<DiscussionCubit>().delete(widget.post.id);
    if (mounted && failure != null) widget.onReport(failure);
  }

  Future<void> _saveEdit() async {
    final content = _editor?.text.trim() ?? '';
    if (content.isEmpty) return;

    final failure =
        await context.read<DiscussionCubit>().edit(widget.post.id, content);
    if (!mounted) return;
    if (failure != null) {
      widget.onReport(failure);
      return;
    }
    _cancelEdit();
  }

  void _cancelEdit() {
    _editor?.dispose();
    setState(() => _editor = null);
  }

  Future<void> _react(String type) async {
    final failure =
        await context.read<DiscussionCubit>().react(widget.post.id, type);
    if (mounted && failure != null) widget.onReport(failure);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final post = widget.post;

    return GestureDetector(
      onLongPress: _editing ? null : _openActions,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppAvatar(
              imageUrl: post.author.avatar,
              name: post.author.displayName,
              size: post.isReply ? 28 : 36,
            ),
            SizedBox(width: post.isReply ? 10 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          post.author.displayName,
                          style: theme.textTheme.labelMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (post.isTeacher) ...[
                        const SizedBox(width: 6),
                        AppBadge('Teacher', shade: TwColors.violet, dense: true),
                      ],
                      const SizedBox(width: 8),
                      Text(
                        Fmt.relative(post.createdAt),
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (_editing) ...[
                    TextField(
                      controller: _editor,
                      autofocus: true,
                      maxLines: null,
                      style: theme.textTheme.bodyMedium,
                      decoration: const InputDecoration(isDense: true),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: _cancelEdit,
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: _saveEdit,
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ] else
                    AppMarkdown(post.content, selectable: false),
                  if (!_editing)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          _ReactionButton(
                            icon: Icons.thumb_up_outlined,
                            activeIcon: Icons.thumb_up_rounded,
                            count: post.likeCount,
                            isActive: post.myReaction == 'like',
                            onTap: () => _react('like'),
                          ),
                          const SizedBox(width: 14),
                          _ReactionButton(
                            icon: Icons.thumb_down_outlined,
                            activeIcon: Icons.thumb_down_rounded,
                            count: post.dislikeCount,
                            isActive: post.myReaction == 'dislike',
                            onTap: () => _react('dislike'),
                          ),
                          if (widget.onReply != null) ...[
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: widget.onReply,
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  'Reply',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.mutedForeground,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (post.isEdited) ...[
                            const SizedBox(width: 12),
                            Text('Edited', style: theme.textTheme.labelSmall),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if ((post.isOwner || widget.canModerate) && !_editing)
              GestureDetector(
                onTap: _openActions,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, top: 2),
                  child: Icon(
                    Icons.more_horiz_rounded,
                    size: 18,
                    color: scheme.mutedForeground,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({
    required this.icon,
    required this.activeIcon,
    required this.count,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final int count;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final colour = isActive ? scheme.primary : scheme.mutedForeground;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4, right: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActive ? activeIcon : icon, size: 15, color: colour),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: colour,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The composer pinned to the foot of the thread.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.replyingTo,
    required this.onCancelReply,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? replyingTo;
  final VoidCallback onCancelReply;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final replyingTo = this.replyingTo;

    final body = Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        10 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (replyingTo != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.reply_rounded,
                    size: 14,
                    color: scheme.mutedForeground,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Replying to $replyingTo',
                      style: Theme.of(context).textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: onCancelReply,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Icon(
                        Icons.close_rounded,
                        size: 15,
                        color: scheme.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _FieldSurface(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    style: Theme.of(context).textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: replyingTo == null
                          ? 'Join the discussion…'
                          : 'Reply to $replyingTo…',
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintStyle: TextStyle(color: scheme.mutedForeground),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final enabled = value.text.trim().isNotEmpty;
                  return GestureDetector(
                    onTap: enabled ? onSend : null,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: enabled
                            ? scheme.primary
                            : scheme.mutedForeground.withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_upward_rounded,
                        size: 19,
                        color: enabled
                            ? scheme.primaryForeground
                            : scheme.mutedForeground,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );

    if (context.useGlass) {
      final glass = context.glass;
      return LiquidGlassContainer(
        blur: GlassBlur.chrome,
        spec: glass.chromeScrolled,
        borderRadius: BorderRadius.zero,
        showBorder: false,
        showShadow: false,
        showHighlight: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Divider(
              height: 0.5,
              thickness: 0.5,
              color: glass.chromeScrolled.borderColor,
            ),
            body,
          ],
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.card,
        border: Border(top: BorderSide(color: scheme.border)),
      ),
      child: body,
    );
  }
}

/// The rounded fill the composer's field sits in.
class _FieldSurface extends StatelessWidget {
  const _FieldSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.symmetric(horizontal: 14, vertical: 10);

    if (context.useGlass) {
      return LiquidGlassContainer(
        spec: context.glass.control,
        radius: GlassRadius.sm,
        showShadow: false,
        padding: padding,
        child: child,
      );
    }

    final scheme = context.scheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.muted,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: scheme.border),
      ),
      child: child,
    );
  }
}
