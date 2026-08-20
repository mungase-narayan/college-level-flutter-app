import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_colors.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/design/animations/glass_curves.dart';
import '../../../../../core/design/extensions/glass_context.dart';
import '../../../../../core/design/theme/glass_specs.dart';
import '../../../../../core/design/utils/glass_haptics.dart';
import '../../../../../core/design/widgets/liquid_glass_container.dart';
import '../../../../../core/error/failures.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../auth/presentation/bloc/auth/auth_bloc.dart';
import '../../domain/entities/material_comment.dart';
import '../bloc/material_comments_cubit.dart';

/// Port of `CommentsSection` for a course material.
///
/// A one-level thread: top-level comments each with their replies. Bodies are
/// rendered through [AppMarkdown], so a comment picks up the same rich blocks
/// the material content does — exactly as on the web, where both go through the
/// shared `Markdown`.
///
/// Laid out as a social comment feed rather than as a list of cards: avatar,
/// name and body in one block, a quiet meta line under it, replies collapsed
/// behind a "View N replies" hairline, and a floating glass composer pinned to
/// the bottom. Row-level actions (edit, delete, copy) live in a long-press
/// action sheet instead of as always-visible links — three tinted words under
/// every comment, one of them red, made the feed read as a list of controls
/// rather than as a conversation.
class MaterialCommentsTab extends StatefulWidget {
  const MaterialCommentsTab({super.key});

  @override
  State<MaterialCommentsTab> createState() => _MaterialCommentsTabState();
}

class _MaterialCommentsTabState extends State<MaterialCommentsTab> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  /// The composer's height with a single-line field: 10pt of padding either side
  /// of a ~40pt capsule. Held as a constant rather than measured because the list
  /// needs it to lay out, which is before the bar has been through layout itself
  /// — and the two states where it grows (a staged reply, a multi-line draft)
  /// both happen with the keyboard up, where the list has already scrolled.
  static const _composerRestingHeight = 60.0;

  /// The comment being replied to, or null when composing a new top-level one.
  String? _replyTo;

  bool _sending = false;

  @override
  void initState() {
    super.initState();
    context.read<MaterialCommentsCubit>().load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _sending) return;

    final cubit = context.read<MaterialCommentsCubit>();
    final target = _replyTo;
    setState(() => _sending = true);
    final failure = target == null
        ? await cubit.post(content)
        : await cubit.replyTo(target, content);

    if (!mounted) return;
    setState(() => _sending = false);
    if (failure != null) {
      _report(failure);
      return;
    }
    GlassHaptics.success();
    _controller.clear();
    setState(() => _replyTo = null);
  }

  /// Aims the composer at [id] and raises the keyboard, so tapping Reply lands
  /// the caret where the user is already looking.
  void _startReply(String id) {
    setState(() => _replyTo = id);
    _focus.requestFocus();
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
    final currentUser = context.select<AuthBloc, ({String? id, String? avatar, String? name})>(
      (bloc) => (
        id: bloc.state.user?.id,
        avatar: bloc.state.user?.avatar,
        name: bloc.state.user?.fullName,
      ),
    );

    // The composer floats *over* the list rather than sitting beside it in a
    // column, so comments scroll under its blur — which is the only thing that
    // makes a glass bar read as glass. The list reserves the bar's resting
    // height at its foot so the last comment still clears it.
    final listBottomInset =
        _composerRestingHeight + MediaQuery.of(context).padding.bottom;

    return Stack(
      children: [
        Positioned.fill(
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
                    padding: EdgeInsets.only(bottom: listBottomInset),
                    children: const [
                      SizedBox(height: 40),
                      AppEmptyState(
                        title: 'No comments yet',
                        description: 'Start the discussion on this material.',
                        icon: Icons.forum_outlined,
                      ),
                    ],
                  );
                }

                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16, 8, 16, listBottomInset + 8),
                  itemCount: comments.length,
                  itemBuilder: (context, index) => _CommentThread(
                    comment: comments[index],
                    currentUserId: currentUser.id,
                    onReply: _startReply,
                    onReport: _report,
                  ),
                );
              },
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _Composer(
            controller: _controller,
            focusNode: _focus,
            avatarUrl: currentUser.avatar,
            userName: currentUser.name,
            isSending: _sending,
            replyingTo: _replyTo == null
                ? null
                : _findAuthor(cubit.state.data, _replyTo!),
            onCancelReply: () => setState(() => _replyTo = null),
            onSubmit: _submit,
          ),
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

/// A top-level comment with its replies collapsed beneath it.
///
/// Replies start hidden behind a "View N replies" line, as they do in every
/// social feed: a thread with a dozen answers otherwise pushes the next
/// conversation entirely off-screen, and the count is the part worth showing at
/// rest.
class _CommentThread extends StatefulWidget {
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
  State<_CommentThread> createState() => _CommentThreadState();
}

class _CommentThreadState extends State<_CommentThread> {
  bool _expanded = false;

  /// Where a reply's avatar starts: the parent's avatar width plus its gutter,
  /// so replies hang directly under the parent's text column.
  static const _replyIndent = _CommentRow.avatarSize + 12;

  @override
  Widget build(BuildContext context) {
    final replies = widget.comment.replies;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CommentRow(
            comment: widget.comment,
            currentUserId: widget.currentUserId,
            // Only a top-level comment can be replied to; the backend rejects a
            // deeper thread with COURSE_COMMENT_REPLY_DEPTH.
            onReply: () => widget.onReply(widget.comment.id),
            onReport: widget.onReport,
          ),
          if (replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: _replyIndent, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RepliesToggle(
                    count: replies.length,
                    expanded: _expanded,
                    onTap: () => setState(() => _expanded = !_expanded),
                  ),
                  if (_expanded)
                    for (final reply in replies)
                      _CommentRow(
                        comment: reply,
                        currentUserId: widget.currentUserId,
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

/// `—— View 2 replies` / `—— Hide replies`.
class _RepliesToggle extends StatelessWidget {
  const _RepliesToggle({
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  final int count;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The stub of rule is what ties the line to the thread above it.
            Container(width: 22, height: 1, color: scheme.border),
            const SizedBox(width: 10),
            Text(
              expanded
                  ? 'Hide replies'
                  : 'View ${count == 1 ? '1 reply' : '$count replies'}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: scheme.mutedForeground,
              ),
            ),
          ],
        ),
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

  /// Avatar diameter of a top-level comment. A reply's is smaller, which is what
  /// makes the indentation read as depth rather than as stray padding.
  static const avatarSize = 36.0;
  static const replyAvatarSize = 28.0;

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
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete comment?',
      message: 'This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    final failure =
        await context.read<MaterialCommentsCubit>().delete(widget.comment.id);
    if (mounted && failure != null) widget.onReport(failure);
  }

  /// The row's actions, as a sheet — reached by long-pressing the comment, or by
  /// the `⋯` that owners get.
  Future<void> _openActions() async {
    final isOwner = widget.comment.isOwnedBy(widget.currentUserId);
    GlassHaptics.light();

    final action = await showAppOptionSheet<String>(
      context,
      title: widget.comment.author.displayName,
      options: [
        if (widget.onReply != null)
          const AppSheetOption(
            value: 'reply',
            label: 'Reply',
            icon: Icons.reply_rounded,
          ),
        const AppSheetOption(
          value: 'copy',
          label: 'Copy text',
          icon: Icons.copy_rounded,
        ),
        if (isOwner) ...[
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
      case 'copy':
        await Clipboard.setData(ClipboardData(text: widget.comment.content));
        if (mounted) AppToast.success(context, 'Comment copied');
      case 'edit':
        _startEdit();
      case 'delete':
        await _delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final comment = widget.comment;
    final isOwner = comment.isOwnedBy(widget.currentUserId);
    final isReply = comment.isReply;
    final size =
        isReply ? _CommentRow.replyAvatarSize : _CommentRow.avatarSize;

    return GestureDetector(
      // The whole row is the target, as it is in a chat: a long press anywhere
      // on a comment raises its actions.
      onLongPress: _editing ? null : _openActions,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppAvatar(
              imageUrl: comment.author.avatar,
              name: comment.author.displayName,
              size: size,
            ),
            SizedBox(width: isReply ? 10 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          comment.author.displayName,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (comment.isTeacher) ...[
                        const SizedBox(width: 6),
                        AppBadge('Teacher', shade: TwColors.violet, dense: true),
                      ],
                      const SizedBox(width: 8),
                      Text(
                        Fmt.relative(comment.createdAt?.toIso8601String()),
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (_editing)
                    _EditField(
                      controller: _editor!,
                      onSave: _saveEdit,
                      onCancel: _cancelEdit,
                    )
                  else
                    AppMarkdown(comment.content, selectable: false),
                  if (!_editing) _MetaRow(
                    onReply: widget.onReply,
                    isEdited: comment.isEdited,
                  ),
                ],
              ),
            ),
            if (isOwner && !_editing)
              // Owners get a visible handle on the same menu the long press
              // opens; a gesture nobody can see is not an affordance.
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

/// The quiet line under a comment body: `Reply · edited`.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.onReply, required this.isEdited});

  final VoidCallback? onReply;
  final bool isEdited;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final style = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      color: scheme.mutedForeground,
    );

    if (onReply == null && !isEdited) return const SizedBox(height: 2);

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          if (onReply != null)
            GestureDetector(
              onTap: onReply,
              behavior: HitTestBehavior.opaque,
              // Vertical padding only: the label must stay flush with the body
              // text above it, so the tap target grows downward instead.
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4, right: 12),
                child: Text('Reply', style: style),
              ),
            ),
          if (isEdited)
            Text(
              'Edited',
              style: style.copyWith(fontWeight: FontWeight.w400),
            ),
        ],
      ),
    );
  }
}

/// Inline editing of an existing comment.
class _EditField extends StatelessWidget {
  const _EditField({
    required this.controller,
    required this.onSave,
    required this.onCancel,
  });

  final TextEditingController controller;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        _FieldSurface(
          child: TextField(
            controller: controller,
            autofocus: true,
            maxLines: null,
            maxLength: 5000,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              counterText: '',
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        Row(
          children: [
            _TextAction(label: 'Cancel', onTap: onCancel, color: scheme.mutedForeground),
            _TextAction(label: 'Save', onTap: onSave, color: scheme.primary),
          ],
        ),
      ],
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({
    required this.label,
    required this.onTap,
    required this.color,
  });

  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      );
}

/// The rounded fill a composer or edit field sits in — glass on iOS, a tinted
/// capsule on Android.
class _FieldSurface extends StatelessWidget {
  const _FieldSurface({required this.child, this.radius = 18});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.symmetric(horizontal: 14, vertical: 10);

    if (context.useGlass) {
      return LiquidGlassContainer(
        spec: context.glass.control,
        radius: radius,
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
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: scheme.border),
      ),
      child: child,
    );
  }
}

/// The composer pinned to the foot of the tab.
///
/// A bar of chrome rather than part of the list: on iOS it takes a real backdrop
/// blur, so comments pass *under* it as they scroll instead of stopping at an
/// opaque strip.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.avatarUrl,
    required this.userName,
    required this.isSending,
    required this.replyingTo,
    required this.onCancelReply,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? avatarUrl;
  final String? userName;
  final bool isSending;
  final String? replyingTo;
  final VoidCallback onCancelReply;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final replyingTo = this.replyingTo;

    final body = Padding(
      // `padding`, not `viewPadding`: the tab is already inside a SafeArea, so
      // the home-indicator reserve has been consumed above and reading the raw
      // view padding here would leave a second empty band under the bar.
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
            _ReplyBanner(name: replyingTo, onCancel: onCancelReply),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppAvatar(imageUrl: avatarUrl, name: userName, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: _FieldSurface(
                  radius: GlassRadius.sm,
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    minLines: 1,
                    maxLines: 5,
                    // The validator caps a comment at 5000 characters.
                    maxLength: 5000,
                    textCapitalization: TextCapitalization.sentences,
                    style: Theme.of(context).textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: replyingTo == null
                          ? 'Add a comment…'
                          : 'Reply to $replyingTo…',
                      isDense: true,
                      border: InputBorder.none,
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                      hintStyle: TextStyle(color: scheme.mutedForeground),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SendButton(
                controller: controller,
                isSending: isSending,
                onSubmit: onSubmit,
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
        // Square and unringed, like the app bar: the composer is flush to the
        // screen edges, so a rounded, outlined surface would read as a floating
        // panel rather than as chrome. The one hairline it does carry is at the
        // top, where comments pass beneath it.
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

/// `Replying to Asha ×` — the chip above the field while a reply is staged.
class _ReplyBanner extends StatelessWidget {
  const _ReplyBanner({required this.name, required this.onCancel});

  final String name;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(Icons.reply_rounded, size: 14, color: scheme.mutedForeground),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Replying to $name',
              style: Theme.of(context).textTheme.labelSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: onCancel,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Icon(
                Icons.close_rounded,
                size: 15,
                color: scheme.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The send control: dimmed and inert until there is something to send.
class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.controller,
    required this.isSending,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSubmit;

  static const _size = 36.0;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final glass = context.glass;

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final enabled = value.text.trim().isNotEmpty && !isSending;

        return GestureDetector(
          onTap: enabled
              ? () {
                  GlassHaptics.light();
                  onSubmit();
                }
              : null,
          behavior: HitTestBehavior.opaque,
          child: AnimatedScale(
            // A nudge in size on becoming usable, which is what draws the eye to
            // the button the moment a comment is worth sending.
            scale: enabled ? 1.0 : 0.9,
            duration: glass.duration(GlassDurations.fast),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: glass.duration(GlassDurations.fast),
              width: _size,
              height: _size,
              decoration: BoxDecoration(
                color: enabled
                    ? scheme.primary
                    : scheme.mutedForeground.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: isSending
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.primaryForeground,
                      ),
                    )
                  : Icon(
                      Icons.arrow_upward_rounded,
                      size: 19,
                      color: enabled
                          ? scheme.primaryForeground
                          : scheme.mutedForeground,
                    ),
            ),
          ),
        );
      },
    );
  }
}
