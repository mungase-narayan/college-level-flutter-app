import 'package:flutter/material.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/note.dart';

/// The four tallies shown above the student's own notes.
class NotesStatsRow extends StatelessWidget {
  const NotesStatsRow({super.key, required this.stats});

  final MyNotesStats stats;

  @override
  Widget build(BuildContext context) => AppStatGrid(
        tiles: [
          AppStatTile(
            label: 'Total views',
            value: Fmt.number(stats.totalViews),
            icon: Icons.visibility_outlined,
            shade: TwColors.teal,
          ),
          AppStatTile(
            label: 'Total likes',
            value: Fmt.number(stats.totalLikes),
            icon: Icons.favorite_border_rounded,
            shade: TwColors.rose,
          ),
          AppStatTile(
            label: 'Comments',
            value: Fmt.number(stats.totalComments),
            icon: Icons.mode_comment_outlined,
            shade: TwColors.violet,
          ),
          AppStatTile(
            label: 'Published notes',
            value: Fmt.number(stats.publishedNotes),
            icon: Icons.check_circle_outline_rounded,
            shade: TwColors.emerald,
          ),
        ],
      );
}
