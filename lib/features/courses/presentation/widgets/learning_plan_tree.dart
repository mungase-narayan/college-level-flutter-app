import 'package:flutter/material.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../domain/entities/course_tree.dart';
import '../pages/material_detail_page.dart';

/// Port of `student/courses/detail/learning-plan/index.tsx`.
///
/// A three-level tree — module → topic → material. Modules start expanded and
/// topics start collapsed, matching `ModuleRow` / `TopicRow`, so a course with
/// twenty topics opens as a scannable outline rather than a wall of rows.
///
/// This is the sidebar half of the web's split view; tapping a material pushes
/// [MaterialDetailPage], which is the content half.
class LearningPlanTree extends StatelessWidget {
  const LearningPlanTree({
    super.key,
    required this.tree,
    required this.onRefresh,
    required this.onToggleMaterial,
  });

  final CourseTree tree;
  final Future<void> Function() onRefresh;
  final ValueChanged<CourseMaterial> onToggleMaterial;

  @override
  Widget build(BuildContext context) {
    if (tree.modules.isEmpty) {
      return const AppEmptyState(
        title: 'No content yet',
        description:
            'Course materials will appear here once your instructor adds them.',
        icon: Icons.auto_stories_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        itemCount: tree.modules.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _ModuleTile(
          module: tree.modules[index],
          number: index + 1,
          // Open the first module so the screen isn't a stack of closed rows.
          initiallyExpanded: index == 0,
          onToggleMaterial: onToggleMaterial,
        ),
      ),
    );
  }
}

/// `01 · Module title · 0/3`, with its topics beneath.
class _ModuleTile extends StatefulWidget {
  const _ModuleTile({
    required this.module,
    required this.number,
    required this.initiallyExpanded,
    required this.onToggleMaterial,
  });

  final CourseModule module;
  final int number;
  final bool initiallyExpanded;
  final ValueChanged<CourseMaterial> onToggleMaterial;

  @override
  State<_ModuleTile> createState() => _ModuleTileState();
}

class _ModuleTileState extends State<_ModuleTile> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final scheme = tokens.scheme;
    final progress = widget.module.progress;

    // The index badge turns emerald once every material in the module is done.
    final isComplete =
        progress.totalMaterials > 0 &&
        progress.completedMaterials == progress.totalMaterials;
    final badgeTone = isComplete ? tokens.success : null;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 12, 14, 12),
              child: Row(
                children: [
                  _Chevron(expanded: _expanded),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeTone?.background ?? scheme.muted,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Text(
                      widget.number.toString().padLeft(2, '0'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: badgeTone?.foreground ?? scheme.mutedForeground,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.module.name,
                      style: theme.textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CountPill(progress: progress),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(height: 1, color: scheme.border.withValues(alpha: 0.6)),
            if (widget.module.topics.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(46, 12, 14, 14),
                child: Text('No topics yet', style: theme.textTheme.labelSmall),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  children: [
                    for (final topic in widget.module.topics)
                      _TopicTile(
                        topic: topic,
                        onToggleMaterial: widget.onToggleMaterial,
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// A collapsible topic. Collapsed by default, as in `TopicRow`.
class _TopicTile extends StatefulWidget {
  const _TopicTile({required this.topic, required this.onToggleMaterial});

  final CourseTopic topic;
  final ValueChanged<CourseMaterial> onToggleMaterial;

  @override
  State<_TopicTile> createState() => _TopicTileState();
}

class _TopicTileState extends State<_TopicTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final materials = widget.topic.materials;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(
              children: [
                _Chevron(expanded: _expanded, size: 16),
                const SizedBox(width: 6),
                Icon(
                  Icons.description_outlined,
                  size: 16,
                  color: scheme.mutedForeground,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.topic.name,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (widget.topic.progress.totalMaterials > 0)
                  _CountPill(progress: widget.topic.progress),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            // Indent past the chevron, and hang the rail under the topic icon.
            padding: const EdgeInsets.only(left: 26),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: scheme.border, width: 1.5),
                ),
              ),
              child: materials.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(18, 4, 14, 10),
                      child: Text(
                        'No materials yet',
                        style: theme.textTheme.labelSmall,
                      ),
                    )
                  : Column(
                      children: [
                        for (final material in materials)
                          _MaterialRow(
                            material: material,
                            onToggle: widget.onToggleMaterial,
                          ),
                      ],
                    ),
            ),
          ),
      ],
    );
  }
}

class _MaterialRow extends StatelessWidget {
  const _MaterialRow({required this.material, required this.onToggle});

  final CourseMaterial material;
  final ValueChanged<CourseMaterial> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final scheme = tokens.scheme;

    final icon = switch (material.kind) {
      MaterialKind.video => Icons.play_circle_outline_rounded,
      MaterialKind.file => Icons.attach_file_rounded,
      MaterialKind.reading => Icons.menu_book_outlined,
    };

    return InkWell(
      onTap: () => MaterialDetailPage.push(
        context,
        courseId: material.courseId,
        materialId: material.id,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
        child: Row(
          children: [
            Icon(
              material.completed ? Icons.check_circle_rounded : icon,
              size: 17,
              color: material.completed
                  ? tokens.success.foreground
                  : scheme.mutedForeground,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                material.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: material.completed
                      ? scheme.mutedForeground
                      : scheme.foreground,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Toggling completion without opening the viewer.
            IconButton(
              onPressed: () => onToggle(material),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
              tooltip: material.completed ? 'Mark incomplete' : 'Mark complete',
              icon: Icon(
                material.completed
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 19,
                color: material.completed
                    ? tokens.success.foreground
                    : scheme.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `0/3` — the completed-of-total pill on module and topic rows.
class _CountPill extends StatelessWidget {
  const _CountPill({required this.progress});

  final CourseProgress progress;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isComplete = progress.totalMaterials > 0 &&
        progress.completedMaterials == progress.totalMaterials;
    final tone = isComplete ? tokens.success : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tone?.background ?? tokens.scheme.muted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${progress.completedMaterials}/${progress.totalMaterials}',
        style: TextStyle(
          color: tone?.foreground ?? tokens.scheme.mutedForeground,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// The disclosure arrow, rotating a quarter turn when open.
class _Chevron extends StatelessWidget {
  const _Chevron({required this.expanded, this.size = 20});

  final bool expanded;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: expanded ? 0 : -0.25,
      duration: const Duration(milliseconds: 160),
      child: Icon(
        Icons.keyboard_arrow_down_rounded,
        size: size,
        color: context.scheme.mutedForeground,
      ),
    );
  }
}
