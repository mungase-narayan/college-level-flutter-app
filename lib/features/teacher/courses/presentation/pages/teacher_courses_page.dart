import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/design/extensions/glass_context.dart';
import '../../../../shared/shell/presentation/pages/app_shell.dart';
import '../../../../shared/shell/presentation/widgets/teacher_nav.dart';
import '../../domain/entities/teacher_course.dart';
import '../bloc/teacher_courses_cubit.dart';
import '../widgets/teacher_course_card.dart';

/// Port of `src/pages/teacher/courses/index.tsx`.
///
/// The web is a table on desktop and cards on mobile; this ports the card
/// branch. Rows arrive one per (course, division) and are folded into one card
/// per course by the cubit, so a teacher taking three sections sees "3 sections"
/// rather than the same course three times.
///
/// The web's two inline selects become one filter button opening a sheet — the
/// same shape every student list uses, which keeps the whole width for search.
class TeacherCoursesPage extends StatefulWidget {
  const TeacherCoursesPage({super.key});

  @override
  State<TeacherCoursesPage> createState() => _TeacherCoursesPageState();
}

class _TeacherCoursesPageState extends State<TeacherCoursesPage> {
  final _filterDraft = ValueNotifier<_CourseFilters>(const _CourseFilters());

  @override
  void initState() {
    super.initState();
    context.read<TeacherCoursesCubit>().load();
  }

  @override
  void dispose() {
    _filterDraft.dispose();
    super.dispose();
  }

  /// Rebuilds after a cubit call so the filter badge and the empty-state copy
  /// follow filters that are held on the cubit rather than in its state.
  Future<void> _apply(Future<void> Function() change) async {
    await change();
    if (mounted) setState(() {});
  }

  Future<void> _openFilters(TeacherCoursesCubit cubit) async {
    // Each opening starts from what is actually applied, so a sheet dismissed
    // without applying leaves nothing behind.
    _filterDraft.value = _CourseFilters(
      status: cubit.status,
      type: cubit.type,
    );

    final applied = await showAppSheet<_CourseFilters>(
      context,
      title: 'Filters',
      builder: (context) => _FilterSheet(draft: _filterDraft),
    );
    if (applied == null || !mounted) return;

    // Type is applied over the loaded list; status is the one the server owns,
    // so it goes last and carries the refetch.
    cubit.setType(applied.type);
    await _apply(() => cubit.setStatus(applied.status));
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TeacherCoursesCubit>();
    final glassInsets = context.glassContentInsets;

    return ShellScaffold(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: AppSearchField(
                    hint: 'Search by name, code, or department',
                    onChanged: (value) => _apply(() async => cubit.setSearch(value)),
                  ),
                ),
                const SizedBox(width: 8),
                _FilterButton(
                  activeCount: _CourseFilters(
                    status: cubit.status,
                    type: cubit.type,
                  ).activeCount,
                  onPressed: () => _openFilters(cubit),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => cubit.load(refresh: true),
              child: RemoteView<TeacherCoursesCubit, List<TeacherCourseGroup>>(
                onRetry: cubit.load,
                // Four rows of two: five of three overflowed the space left
                // under the search bar on a 390pt viewport.
                loading: const Padding(
                  padding: EdgeInsets.all(16),
                  child: AppListSkeleton(rows: 4, lines: 2),
                ),
                builder: (context, groups) {
                  if (groups.isEmpty) {
                    // The copy splits on whether anything is filtered, so an
                    // empty result never reads as "you have no courses".
                    return AppEmptyState(
                      icon: Icons.menu_book_outlined,
                      title: cubit.hasFilters
                          ? 'No courses match your filters'
                          : 'No courses assigned',
                      description: cubit.hasFilters
                          ? 'Try adjusting your search or filters.'
                          : 'Your assigned courses will appear here once the '
                              'admin sets them up.',
                    );
                  }

                  return ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      4,
                      16,
                      20 + glassInsets.bottom,
                    ),
                    itemCount: groups.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => StaggeredEntrance(
                      index: index,
                      child: TeacherCourseCard(
                        group: groups[index],
                        onTap: () => context.push(
                          TeacherRoutes.course(groups[index].course.id),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What the filter sheet is editing.
class _CourseFilters {
  const _CourseFilters({this.status, this.type});

  final String? status;
  final String? type;

  int get activeCount => (status == null ? 0 : 1) + (type == null ? 0 : 1);
}

/// The filter entry point: an icon that carries a count when filters are on.
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.activeCount, required this.onPressed});

  final int activeCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final theme = Theme.of(context);
    final isActive = activeCount > 0;

    return IconButton(
      tooltip: isActive ? 'Filters ($activeCount applied)' : 'Filters',
      onPressed: onPressed,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            Icons.tune_rounded,
            // Tinted while filtered, so the list never looks unexpectedly short
            // with no visible reason why.
            color: isActive ? scheme.primary : null,
          ),
          if (isActive)
            Positioned(
              top: -5,
              right: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(minWidth: 15),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$activeCount',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.primaryForeground,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterSheet extends StatelessWidget {
  const _FilterSheet({required this.draft});

  final ValueNotifier<_CourseFilters> draft;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_CourseFilters>(
      valueListenable: draft,
      builder: (context, value, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppOptionGroup<String?>(
            header: 'Status',
            selected: value.status,
            onSelected: (status) =>
                draft.value = _CourseFilters(status: status, type: value.type),
            options: const [
              AppOptionItem(
                value: null,
                label: 'All statuses',
                icon: Icons.apps_rounded,
              ),
              AppOptionItem(
                value: CourseStatus.draft,
                label: 'Draft',
                icon: Icons.edit_note_rounded,
              ),
              AppOptionItem(
                value: CourseStatus.active,
                label: 'Active',
                icon: Icons.play_circle_outline_rounded,
              ),
              AppOptionItem(
                value: CourseStatus.archived,
                label: 'Archived',
                icon: Icons.archive_outlined,
              ),
            ],
          ),
          AppOptionGroup<String?>(
            header: 'Type',
            selected: value.type,
            onSelected: (type) =>
                draft.value = _CourseFilters(status: value.status, type: type),
            options: [
              const AppOptionItem(
                value: null,
                label: 'All types',
                icon: Icons.apps_rounded,
              ),
              for (final type in CourseType.options)
                AppOptionItem(
                  value: type,
                  label: CourseType.label(type),
                  icon: Icons.category_outlined,
                ),
            ],
          ),
          AppFilterActions(
            // Disabled at defaults, so the button never implies there is
            // something to clear when there is not.
            onReset: value.activeCount == 0
                ? null
                : () => draft.value = const _CourseFilters(),
            onApply: () => Navigator.of(context).pop(value),
          ),
        ],
      ),
    );
  }
}
