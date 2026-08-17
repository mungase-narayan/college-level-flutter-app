import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/note.dart';
import '../bloc/material_notes_cubit.dart';

/// Port of `NotesSection` scoped to one thing: the notes filed against it, plus
/// a composer that pre-links a new one.
///
/// What it is scoped *to* comes from the ambient `MaterialNotesCubit`'s
/// [NoteLinkContext], so the same tab serves a course material and a practice
/// question; [subject] is only the word the copy uses.
///
/// The full notes hub — detail, likes, note comments, sharing — is a later
/// pass; this is only the embedded list a tab shows.
class MaterialNotesTab extends StatefulWidget {
  const MaterialNotesTab({super.key, this.subject = 'material'});

  /// Named in the composer's subtitle and the empty state.
  final String subject;

  @override
  State<MaterialNotesTab> createState() => _MaterialNotesTabState();
}

class _MaterialNotesTabState extends State<MaterialNotesTab> {
  @override
  void initState() {
    super.initState();
    context.read<MaterialNotesCubit>().load();
  }

  Future<void> _compose() async {
    final cubit = context.read<MaterialNotesCubit>();

    final draft = await showAppSheet<_NoteDraft>(
      context,
      title: 'New note',
      subtitle: 'Linked to this ${widget.subject}.',
      builder: (_) => const _NoteComposer(),
    );
    if (draft == null || !mounted) return;

    final failure = await cubit.create(
      title: draft.title,
      content: draft.content,
      tags: draft.tags,
      visibility: draft.visibility,
    );
    if (!mounted) return;

    if (failure != null) {
      AppToast.failure(context, failure);
    } else {
      AppToast.success(context, 'Note created');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<MaterialNotesCubit>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Notes shared for this ${widget.subject}.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 10),
              AppButton(
                label: 'New note',
                icon: Icons.add_rounded,
                size: AppButtonSize.sm,
                onPressed: _compose,
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => cubit.load(refresh: true),
            child: RemoteView<MaterialNotesCubit, List<NoteListItem>>(
              onRetry: cubit.load,
              loading: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: AppListSkeleton(rows: 2),
              ),
              builder: (context, notes) {
                if (notes.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 28),
                      AppEmptyState(
                        title: 'No notes yet',
                        description:
                            'Be the first to write a note for this ${widget.subject}.',
                        icon: Icons.sticky_note_2_outlined,
                      ),
                    ],
                  );
                }

                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: notes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _NoteRow(note: notes[index]),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// One row of the list — the port of `NoteListRow`.
class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.note});

  final NoteListItem note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppAvatar(
                imageUrl: note.author.avatar,
                name: note.author.displayName,
                size: 30,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(note.title, style: theme.textTheme.titleSmall),
                    Text(
                      '${note.author.displayName} · '
                      '${Fmt.relative(note.createdAt?.toIso8601String())}',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              if (note.isPrivate)
                AppBadge(
                  'Private',
                  icon: Icons.lock_outline_rounded,
                  shade: TwColors.slate,
                  dense: true,
                ),
            ],
          ),
          if (note.excerpt.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              note.excerpt,
              style: theme.textTheme.bodySmall,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (note.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in note.tags)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: scheme.muted,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(tag, style: theme.textTheme.labelSmall),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _Metric(icon: Icons.favorite_border_rounded, value: note.likeCount),
              const SizedBox(width: 14),
              _Metric(
                icon: Icons.mode_comment_outlined,
                value: note.commentCount,
              ),
              const SizedBox(width: 14),
              _Metric(
                icon: Icons.visibility_outlined,
                value: note.viewCount,
              ),
              if (note.attachmentCount > 0) ...[
                const SizedBox(width: 14),
                _Metric(
                  icon: Icons.attach_file_rounded,
                  value: note.attachmentCount,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value});

  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: scheme.mutedForeground),
        const SizedBox(width: 4),
        Text(
          '$value',
          style: TextStyle(fontSize: 12, color: scheme.mutedForeground),
        ),
      ],
    );
  }
}

class _NoteDraft {
  const _NoteDraft({
    required this.title,
    required this.content,
    required this.tags,
    required this.visibility,
  });

  final String title;
  final String content;
  final List<String> tags;
  final String visibility;
}

/// The create form — the mobile form of `NoteEditorDialog`.
class _NoteComposer extends StatefulWidget {
  const _NoteComposer();

  @override
  State<_NoteComposer> createState() => _NoteComposerState();
}

class _NoteComposerState extends State<_NoteComposer> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _tags = TextEditingController();

  String _visibility = 'published';
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _tags.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _title.text.trim();
    final content = _content.text.trim();
    if (title.isEmpty || content.isEmpty) {
      setState(() => _error = 'A note needs a title and a body.');
      return;
    }

    Navigator.of(context).pop(
      _NoteDraft(
        title: title,
        content: content,
        tags: _tags.text
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList(growable: false),
        visibility: _visibility,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppInput(controller: _title, label: 'Title', hint: 'What is this about?'),
        const SizedBox(height: 14),
        AppInput(
          controller: _content,
          label: 'Body',
          // Markdown, so a note can carry the same rich blocks a material can.
          hint: 'Markdown is supported.',
          maxLines: 8,
          minLines: 4,
        ),
        const SizedBox(height: 14),
        AppInput(
          controller: _tags,
          label: 'Tags',
          hint: 'Comma separated',
        ),
        const SizedBox(height: 14),
        AppSelect<String>(
          label: 'Visibility',
          value: _visibility,
          items: const [
            AppSelectItem(value: 'published', label: 'Published'),
            AppSelectItem(value: 'private', label: 'Private'),
          ],
          onChanged: (value) =>
              setState(() => _visibility = value ?? 'published'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.scheme.destructive,
            ),
          ),
        ],
        const SizedBox(height: 18),
        AppButton(label: 'Create note', expand: true, onPressed: _submit),
      ],
    );
  }
}
