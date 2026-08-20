import 'package:flutter/material.dart';

import '../../../../../core/config/theme/app_colors.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../domain/entities/note.dart';

/// The upvote control, shared by the feed card and the detail screen.
///
/// Takes [NoteBase], so it serves both without either page knowing which shape
/// the other holds.
class NoteLikeButton extends StatelessWidget {
  const NoteLikeButton({
    super.key,
    required this.note,
    required this.onPressed,
    this.dense = false,
  });

  final NoteBase note;
  final VoidCallback onPressed;

  /// The card's tighter treatment; the detail uses the roomier pill.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final tone = context.tokens.tone(TwColors.rose);

    final colour = note.liked ? tone.foreground : scheme.mutedForeground;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 4 : 10,
          vertical: dense ? 2 : 6,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              note.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: dense ? 14 : 17,
              color: colour,
            ),
            const SizedBox(width: 5),
            Text(
              NoteMeta.compact(note.likeCount),
              style: (dense ? theme.textTheme.labelSmall : theme.textTheme.bodySmall)
                  ?.copyWith(
                color: colour,
                fontWeight: note.liked ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
