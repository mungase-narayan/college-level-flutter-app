import 'package:flutter/material.dart';

import '../../../../../core/config/theme/app_theme.dart';

/// Marks a tree row as school-wide, and explains what that means.
///
/// Content the admin authored has `divisionId: null` and belongs to every
/// division of the course. Teachers may read it and add their own topics and
/// materials **inside** it, but never edit or delete it — the server answers
/// 403 `COURSE_CONTENT_READ_ONLY`. Since the row simply has no menu, the badge
/// is the only thing telling the teacher why.
class ScopeBadge extends StatelessWidget {
  const ScopeBadge({super.key, this.creator});

  /// Who wrote it, when the tree says.
  final String? creator;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final by = (creator ?? '').isEmpty ? 'an administrator' : creator!;

    return Tooltip(
      message: 'School-wide content added by $by — read-only. You can still '
          'add your own topics and materials inside it.',
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 4),
      child: Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.public_rounded, size: 12, color: scheme.primary),
      ),
    );
  }
}
