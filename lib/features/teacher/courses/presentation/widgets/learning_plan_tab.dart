import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../shared/auth/presentation/bloc/auth/auth_bloc.dart';
import '../../domain/entities/teacher_course_tree.dart';
import '../bloc/course_content_cubit.dart';
import '../bloc/teacher_course_detail_cubit.dart';
import '../pages/teacher_material_page.dart';
import 'content_form_sheets.dart';
import 'scope_badge.dart';

/// Port of `.../detail/learning-plan/index.tsx`.
///
/// The web is a resizable two-pane master/detail. On a phone the tree *is* the
/// tab and a material opens as its own screen — the same shape the student
/// learning plan uses, whose card treatment this shares so the two areas read
/// as one app. What differs is only what a teacher may *do*: the row menus,
/// the add buttons, and the school-wide badges.
class LearningPlanTab extends StatelessWidget {
  const LearningPlanTab({
    super.key,
    required this.tree,
    required this.courseId,
    required this.divisionId,
  });

  final TeacherCourseTree tree;
  final String courseId;
  final String divisionId;

  @override
  Widget build(BuildContext context) {
    final userId = context.select((AuthBloc bloc) => bloc.state.user?.id) ?? '';

    return Column(
      children: [
        _Header(courseId: courseId, divisionId: divisionId),
        Expanded(
          child: tree.modules.isEmpty
              ? AppEmptyState(
                  icon: Icons.auto_stories_outlined,
                  title: 'No modules yet',
                  description:
                      'Add your first module to start building the curriculum.',
                  action: AppButton(
                    label: 'Add module',
                    onPressed: () => showModuleSheet(
                      context,
                      courseId: courseId,
                      divisionId: divisionId,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                  itemCount: tree.modules.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _ModuleTile(
                    module: tree.modules[index],
                    number: index + 1,
                    courseId: courseId,
                    divisionId: divisionId,
                    currentUserId: userId,
                  ),
                ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.courseId, required this.divisionId});

  final String courseId;
  final String divisionId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    // A chrome strip, not a row floating over the list: the tree scrolls
    // directly beneath it, and without the rule a scrolled card ran straight
    // into the button with nothing separating them.
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.border)),
      ),
      child: Row(
        // spaceBetween rather than a Spacer: a Spacer is `Expanded`, which
        // would compete with the Flexible title for the free space instead of
        // simply pushing the button to the edge.
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Flexible, not a bare Text: the Material button is wider than the
          // glass one, and at 390pt the pair overflowed the row on Android
          // while fitting on iOS. Letting the label yield resolves it on both.
          Flexible(
            child: Padding(
              // Keeps the label off the button when the title is long enough
              // to close the gap.
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                'Curriculum',
                style: theme.textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          AppButton(
            label: 'Add module',
            icon: Icons.add_rounded,
            size: AppButtonSize.sm,
            // Outline rather than filled: it sits in a header rule beside a
            // section label, where a solid pill outweighed the tree it belongs
            // to. Matches how the student list headers carry their one action.
            variant: AppButtonVariant.outline,
            onPressed: () => showModuleSheet(
              context,
              courseId: courseId,
              divisionId: divisionId,
            ),
          ),
        ],
      ),
    );
  }
}

/// `01 · Module title · 3`, with its topics beneath — the student module card,
/// plus the teacher's row menu and add-topic affordance.
class _ModuleTile extends StatefulWidget {
  const _ModuleTile({
    required this.module,
    required this.number,
    required this.courseId,
    required this.divisionId,
    required this.currentUserId,
  });

  final TeacherModule module;
  final int number;
  final String courseId;
  final String divisionId;
  final String currentUserId;

  @override
  State<_ModuleTile> createState() => _ModuleTileState();
}

class _ModuleTileState extends State<_ModuleTile> {
  /// Modules open by default — the web expands every one on load, and a
  /// teacher lands here to work inside them.
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final module = widget.module;
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final canManage = module.canManage(widget.currentUserId);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            child: Padding(
              padding: EdgeInsets.fromLTRB(10, 12, canManage ? 4 : 14, 12),
              child: Row(
                children: [
                  _Chevron(expanded: _expanded),
                  const SizedBox(width: 4),
                  _IndexBadge(number: widget.number),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      module.name,
                      style: theme.textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (module.isGlobal) ...[
                    ScopeBadge(creator: module.scope.creator?.fullName),
                    const SizedBox(width: 6),
                  ],
                  _CountPill(count: module.topics.length),
                  if (canManage)
                    _RowMenu(
                      label: module.name,
                      onEdit: () => showModuleSheet(
                        context,
                        courseId: widget.courseId,
                        divisionId: widget.divisionId,
                        module: module,
                      ),
                      onDelete: () => _deleteModule(context, module),
                    ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(height: 1, color: scheme.border.withValues(alpha: 0.6)),
            if (module.topics.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(46, 12, 14, 4),
                child: Text('No topics yet', style: theme.textTheme.labelSmall),
              )
            else
              Column(
                children: [
                  for (final topic in module.topics)
                    _TopicTile(
                      topic: topic,
                      courseId: widget.courseId,
                      divisionId: widget.divisionId,
                      currentUserId: widget.currentUserId,
                    ),
                ],
              ),
            // Always offered, even inside school-wide content — adding your own
            // topics to an admin module is exactly how a teacher extends it.
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
              child: _AddButton(
                label: 'Add topic',
                onPressed: () => showTopicSheet(
                  context,
                  courseId: widget.courseId,
                  divisionId: widget.divisionId,
                  moduleId: module.id,
                  moduleName: module.name,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _deleteModule(BuildContext context, TeacherModule module) async {
    // The web deletes straight from the kebab with no confirmation; on touch
    // that is one mis-tap away from losing a whole module's content.
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete module?',
      message: '"${module.name}" and everything inside it will be removed.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await _runDelete(
      context,
      () => context.read<CourseContentCubit>().deleteModule(module.id),
      success: '"${module.name}" removed',
    );
  }
}

/// A collapsible topic. Collapsed by default, as in the web's `TopicRow`.
class _TopicTile extends StatefulWidget {
  const _TopicTile({
    required this.topic,
    required this.courseId,
    required this.divisionId,
    required this.currentUserId,
  });

  final TeacherTopic topic;
  final String courseId;
  final String divisionId;
  final String currentUserId;

  @override
  State<_TopicTile> createState() => _TopicTileState();
}

class _TopicTileState extends State<_TopicTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final topic = widget.topic;
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final canManage = topic.canManage(widget.currentUserId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: EdgeInsets.fromLTRB(14, 10, canManage ? 4 : 14, 10),
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
                    topic.name,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (topic.isGlobal) ...[
                  ScopeBadge(creator: topic.scope.creator?.fullName),
                  const SizedBox(width: 6),
                ],
                if (topic.materials.isNotEmpty)
                  _CountPill(count: topic.materials.length),
                if (canManage)
                  _RowMenu(
                    label: topic.name,
                    onEdit: () => showTopicSheet(
                      context,
                      courseId: widget.courseId,
                      divisionId: widget.divisionId,
                      moduleId: topic.courseModuleId,
                      moduleName: '',
                      topic: topic,
                    ),
                    onDelete: () => _deleteTopic(context, topic),
                  ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (topic.materials.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 4, 14, 4),
                      child: Text(
                        'No materials yet',
                        style: theme.textTheme.labelSmall,
                      ),
                    )
                  else
                    for (final material in topic.materials)
                      _MaterialRow(
                        material: material,
                        courseId: widget.courseId,
                        divisionId: widget.divisionId,
                        currentUserId: widget.currentUserId,
                        topicName: topic.name,
                      ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                    child: _AddButton(
                      label: 'Add material',
                      onPressed: () => showMaterialSheet(
                        context,
                        courseId: widget.courseId,
                        divisionId: widget.divisionId,
                        moduleId: topic.courseModuleId,
                        topicId: topic.id,
                        topicName: topic.name,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _deleteTopic(BuildContext context, TeacherTopic topic) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete topic?',
      message: '"${topic.name}" and its materials will be removed.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await _runDelete(
      context,
      () => context.read<CourseContentCubit>().deleteTopic(topic.id),
      success: '"${topic.name}" removed',
    );
  }
}

class _MaterialRow extends StatelessWidget {
  const _MaterialRow({
    required this.material,
    required this.courseId,
    required this.divisionId,
    required this.currentUserId,
    required this.topicName,
  });

  final TeacherMaterial material;
  final String courseId;
  final String divisionId;
  final String currentUserId;
  final String topicName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final canManage = material.canManage(currentUserId);

    final icon = switch (material.kind) {
      TeacherMaterialKind.video => Icons.play_circle_outline_rounded,
      TeacherMaterialKind.file => Icons.attach_file_rounded,
      TeacherMaterialKind.reading => Icons.menu_book_outlined,
    };

    return InkWell(
      onTap: () => TeacherMaterialPage.push(
        context,
        courseId: courseId,
        materialId: material.id,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 8, canManage ? 4 : 10, 8),
        child: Row(
          children: [
            Icon(icon, size: 17, color: scheme.mutedForeground),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                material.name,
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (material.isGlobal) ...[
              const SizedBox(width: 8),
              ScopeBadge(creator: material.scope.creator?.fullName),
            ],
            if (canManage)
              _RowMenu(
                label: material.name,
                onEdit: () => showMaterialSheet(
                  context,
                  courseId: courseId,
                  divisionId: divisionId,
                  moduleId: material.courseModuleId,
                  topicId: material.courseTopicId,
                  topicName: topicName,
                  material: material,
                ),
                onDelete: () => _delete(context),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete material?',
      message: '"${material.name}" will be removed.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await _runDelete(
      context,
      () => context.read<CourseContentCubit>().deleteMaterial(material.id),
      success: '"${material.name}" removed',
    );
  }
}

/// Runs a delete, reports it, and reloads the tree.
///
/// Reload is unconditional on success because the server owns ordering — the
/// same reason the web invalidates the whole course prefix.
Future<void> _runDelete(
  BuildContext context,
  Future<dynamic> Function() action, {
  required String success,
}) async {
  final detail = context.read<TeacherCourseDetailCubit>();
  final failure = await action();
  if (!context.mounted) return;

  if (failure != null) {
    AppToast.error(context, failure.message as String);
    return;
  }
  AppToast.success(context, success);
  await detail.reloadTree();
}

/// `01`, `02`, … — the module's position, as the web renders it.
class _IndexBadge extends StatelessWidget {
  const _IndexBadge({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.muted,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Text(
        number.toString().padLeft(2, '0'),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.mutedForeground,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
      ),
    );
  }
}

/// The child count on a module or topic row.
///
/// The student's pill reads `done/total`; a teacher has no completion to show,
/// so it carries the plain count in the same shape.
class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.muted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: scheme.mutedForeground,
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

class _AddButton extends StatelessWidget {
  const _AddButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: scheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 15, color: scheme.mutedForeground),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

/// Edit / Delete for one tree row.
///
/// An action **sheet**, not a `PopupMenuButton`: an anchored popup has to guess
/// where it fits beside a deeply indented row, and under the glass theme it
/// rendered as bare text floating over the tree with no surface behind it. The
/// sheet is also the idiom every other choice in this app uses, and it gives
/// the destructive row a real tap target.
class _RowMenu extends StatelessWidget {
  const _RowMenu({
    required this.label,
    required this.onEdit,
    required this.onDelete,
  });

  /// What is being acted on — titles the sheet, so the reader knows which of
  /// several similarly named rows they opened.
  final String label;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return IconButton(
      tooltip: 'Actions',
      onPressed: () => _open(context),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      icon: Icon(
        Icons.more_vert_rounded,
        size: 18,
        color: scheme.mutedForeground,
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final action = await showAppOptionSheet<String>(
      context,
      title: label,
      options: const [
        AppSheetOption(
          value: 'edit',
          label: 'Edit',
          icon: Icons.edit_outlined,
        ),
        AppSheetOption(
          value: 'delete',
          label: 'Delete',
          icon: Icons.delete_outline_rounded,
          destructive: true,
        ),
      ],
    );
    if (action == null || !context.mounted) return;
    action == 'edit' ? onEdit() : onDelete();
  }
}
