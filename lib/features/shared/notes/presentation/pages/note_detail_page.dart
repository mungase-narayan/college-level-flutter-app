import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_colors.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../shell/presentation/widgets/student_nav.dart';
import '../../domain/entities/note.dart';
import '../bloc/note_detail_cubit.dart';
import '../widgets/note_composer_sheet.dart';
import '../widgets/note_like_button.dart';

/// Port of `src/components/notes/note-detail-page.tsx`.
///
/// Comments and sharing are a later pass; the comment count still renders,
/// because it is a real number.
class NoteDetailPage extends StatefulWidget {
  const NoteDetailPage({super.key});

  @override
  State<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends State<NoteDetailPage> {
  @override
  void initState() {
    super.initState();
    context.read<NoteDetailCubit>().load();
  }

  Future<void> _edit(NoteDetail note) async {
    final cubit = context.read<NoteDetailCubit>();

    final saved = await showNoteComposer(
      context,
      initial: NoteDraft(
        title: note.title,
        content: note.content,
        tags: note.tags,
        visibility: note.visibility,
      ),
      onSubmit: (draft) => cubit.update(
        UpdateNoteInput(
          id: note.id,
          title: draft.title,
          content: draft.content,
          tags: draft.tags,
          visibility: draft.visibility,
        ),
      ),
    );

    if (saved == true && mounted) AppToast.success(context, 'Note updated.');
  }

  Future<void> _delete(NoteDetail note) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete this note?',
      message: "This permanently removes the note and its comments. This can't "
          'be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    final cubit = context.read<NoteDetailCubit>();
    final failure = await cubit.delete();
    if (!mounted) return;

    if (failure != null) {
      AppToast.failure(context, failure);
      return;
    }
    AppToast.success(context, 'Note deleted.');
    // `go`, not `pop`: this route is deep-linkable, so there may be nothing
    // behind it — and the note it would pop back to no longer exists.
    context.go(StudentRoutes.notes);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NoteDetailCubit>();

    return BlocBuilder<NoteDetailCubit, RemoteState<NoteDetail>>(
      builder: (context, state) {
        final note = state.data;

        return Scaffold(
          appBar: AdaptiveAppBar(
            title: 'Note',
            actions: [
              // A student is never a moderator, so ownership is the whole test.
              if (note != null && note.isOwner) ...[
                IconButton(
                  tooltip: 'Edit note',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _edit(note),
                ),
                IconButton(
                  tooltip: 'Delete note',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => _delete(note),
                ),
              ],
            ],
          ),
          body: switch (note) {
            null when state.isInitialLoading => const _DetailSkeleton(),
            // A 403 on someone else's private note and a 404 both land here on
            // purpose: saying "not allowed" would confirm the note exists.
            null => AppEmptyState(
                icon: Icons.sticky_note_2_outlined,
                title: 'Note not found',
                description: 'It may have been removed or is private.',
                action: AppButton(
                  label: 'Back to notes',
                  variant: AppButtonVariant.outline,
                  onPressed: () => context.go(StudentRoutes.notes),
                ),
              ),
            _ => _Body(note: note, onLike: () => _like(cubit)),
          },
        );
      },
    );
  }

  Future<void> _like(NoteDetailCubit cubit) async {
    final failure = await cubit.toggleLike();
    if (failure != null && mounted) AppToast.failure(context, failure);
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.note, required this.onLike});

  final NoteDetail note;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    final role = NoteMeta.roleBadge(note.authorRole);
    final meta = [
      if (note.createdAt != null)
        Fmt.longDate(note.createdAt!.toIso8601String()),
      '${NoteMeta.readingMinutes(note.content)} min read',
      '${note.viewCount} ${note.viewCount == 1 ? 'view' : 'views'}',
      if (note.isEdited) 'edited',
    ].join(' · ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text(note.title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        Row(
          children: [
            AppAvatar(
              imageUrl: note.author.avatar,
              name: note.author.displayName,
              size: 32,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                note.isOwner ? 'You' : note.author.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (role != null) ...[
              const SizedBox(width: 6),
              AppBadge(role, shade: TwColors.violet, dense: true),
            ],
            const Spacer(),
            if (note.isPrivate)
              AppBadge(
                'Private',
                icon: Icons.lock_outline_rounded,
                shade: TwColors.slate,
                dense: true,
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(meta, style: theme.textTheme.labelSmall),
        if (note.tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              // Display only: there is no feed on this screen to filter.
              for (final tag in note.tags)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.muted,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '#$tag',
                    style: theme.textTheme.labelSmall?.copyWith(fontSize: 11),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Divider(color: scheme.border.withValues(alpha: 0.6)),
        const SizedBox(height: 12),
        AppMarkdown(note.content),
        if (note.attachmentFiles.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Attachments (${note.attachmentFiles.length})',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          // Read-only: uploading is a later pass, but a note written on the web
          // can carry files and hiding them would strand them.
          for (final file in note.attachmentFiles)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AttachmentRow(file: file),
            ),
        ],
        const SizedBox(height: 20),
        Divider(color: scheme.border.withValues(alpha: 0.6)),
        const SizedBox(height: 6),
        Row(
          children: [
            NoteLikeButton(note: note, onPressed: onLike),
            const SizedBox(width: 16),
            Icon(
              Icons.mode_comment_outlined,
              size: 16,
              color: scheme.mutedForeground,
            ),
            const SizedBox(width: 6),
            Text(
              NoteMeta.compact(note.commentCount),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({required this.file});

  final NoteAttachment file;

  Future<void> _open(BuildContext context) async {
    final uri = Uri.tryParse(file.url);
    final launched = uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      AppToast.error(context, 'Could not open this attachment.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return AppCard(
      onTap: () => _open(context),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.muted,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(
              Icons.insert_drive_file_outlined,
              size: 16,
              color: scheme.mutedForeground,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              file.name.isEmpty ? 'Attachment' : file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Icon(
            Icons.download_rounded,
            size: 18,
            color: scheme.mutedForeground,
          ),
        ],
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSkeleton(height: 26),
            SizedBox(height: 14),
            AppSkeleton(height: 32, width: 180),
            SizedBox(height: 20),
            AppSkeleton(height: 14),
            SizedBox(height: 8),
            AppSkeleton(height: 14),
            SizedBox(height: 8),
            AppSkeleton(height: 14, width: 220),
          ],
        ),
      );
}
