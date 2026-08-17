import 'package:flutter/material.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../domain/entities/note.dart';
import 'note_like_button.dart';

/// One note in the feed — the port of `NoteCard`.
class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onLike,
    this.onTagTap,
  });

  final NoteListItem note;
  final VoidCallback onTap;
  final VoidCallback onLike;

  /// Tapping a tag filters the feed by it. Not offered by the embedded tabs,
  /// which have no feed to filter.
  final ValueChanged<String>? onTagTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    final role = NoteMeta.roleBadge(note.authorRole);
    final byline = note.isOwner ? 'You' : note.author.displayName;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(
                imageUrl: note.author.avatar,
                name: note.author.displayName,
                size: 28,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'by $byline',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                ),
              ),
              // Only a teacher or an admin is called out; a student note shows
              // no role at all.
              if (role != null) ...[
                const SizedBox(width: 6),
                AppBadge(role, shade: TwColors.violet, dense: true),
              ],
              const Spacer(),
              if (note.isLinked) ...[
                Icon(
                  Icons.link_rounded,
                  size: 14,
                  color: scheme.mutedForeground,
                ),
                const SizedBox(width: 6),
              ],
              if (note.isPrivate)
                AppBadge(
                  'Private',
                  icon: Icons.lock_outline_rounded,
                  shade: TwColors.slate,
                  dense: true,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            note.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
          if (note.excerpt.isNotEmpty) ...[
            const SizedBox(height: 4),
            // Plain text on purpose: the server flattens the markdown into
            // this excerpt itself, and the web renders it verbatim too — down
            // to the leading dashes its regex leaves behind.
            Text(
              note.excerpt,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall,
            ),
          ],
          if (note.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in note.tags) _TagChip(tag: tag, onTap: onTagTap),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              NoteLikeButton(note: note, onPressed: onLike, dense: true),
              const SizedBox(width: 12),
              _Metric(
                icon: Icons.mode_comment_outlined,
                value: NoteMeta.compact(note.commentCount),
              ),
              const SizedBox(width: 12),
              _Metric(
                icon: Icons.visibility_outlined,
                // The web prints an em dash rather than a zero here.
                value: note.viewCount > 0
                    ? NoteMeta.compact(note.viewCount)
                    : '—',
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  // Off `updatedAt`, not `createdAt` — the web labels it
                  // "Edited" for exactly that reason.
                  'Edited ${NoteMeta.timeAgo(note.updatedAt ?? note.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag, this.onTap});

  final String tag;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return InkWell(
      onTap: onTap == null ? null : () => onTap!(tag),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: scheme.muted,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '#$tag',
          style: theme.textTheme.labelSmall?.copyWith(fontSize: 11),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: scheme.mutedForeground),
        const SizedBox(width: 5),
        Text(value, style: theme.textTheme.labelSmall),
      ],
    );
  }
}
