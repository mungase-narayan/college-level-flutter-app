import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_colors.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/design/extensions/glass_context.dart';
import '../../../../../core/network/api_response.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../shared/shell/presentation/pages/app_shell.dart';
import '../../../../shared/shell/presentation/widgets/student_nav.dart';
import '../../domain/entities/student_assessment.dart';
import '../bloc/quizzes_cubit.dart';

/// Port of `src/pages/student/quiz/index.tsx` — every quiz across the student's
/// enrolled courses, in one list.
///
/// The web renders a card grid on phones and a seven-column table on desktop,
/// paginated ten at a time. Here it is one card per quiz with infinite scroll,
/// and the two dropdowns (course, status) move into a filter sheet — the same
/// arrangement the Practice page uses, so the app has one way to filter a list
/// rather than two.
///
/// Status is a *filter* here, not a grouping. The in-course tab groups quizzes
/// under Not Started → In Progress → … with [AssessmentBoard], which only works
/// when the whole list is in hand; over a paginated feed a page boundary would
/// split a group and print its header twice.
class QuizzesPage extends StatefulWidget {
  const QuizzesPage({super.key});

  @override
  State<QuizzesPage> createState() => _QuizzesPageState();
}

class _QuizzesPageState extends State<QuizzesPage> {
  /// What the open filter sheet has staged so far.
  ///
  /// Owned by the page rather than by the sheet because the sheet's header
  /// actions need it too, and they are siblings of the sheet's body rather than
  /// descendants of it. Kept for the page's lifetime instead of one per opening,
  /// so it is never disposed while the sheet is still animating out.
  final _filterDraft = ValueNotifier(const _QuizFilters());

  @override
  void initState() {
    super.initState();
    context.read<QuizzesCubit>().load();
  }

  @override
  void dispose() {
    _filterDraft.dispose();
    super.dispose();
  }

  /// Runs a query change, then rebuilds.
  ///
  /// The filter badge and the empty-state copy are both read off `cubit.query`,
  /// which is deliberately *not* part of the emitted state — so a search or a
  /// filter that changes nothing about the returned page would otherwise leave
  /// the page saying "No quizzes yet" while a search term is in the field.
  Future<void> _apply(Future<void> Function() change) async {
    await change();
    if (mounted) setState(() {});
  }

  Future<void> _openFilters(QuizzesCubit cubit) async {
    // Fetched here rather than on page load: only the sheet needs them, and
    // most visits never open it.
    final courses = await cubit.courseOptions();
    if (!mounted) return;

    // Each opening starts from what is actually applied, so a sheet that was
    // dismissed without applying leaves nothing behind.
    _filterDraft.value = _QuizFilters(
      courseId: cubit.query.courseId,
      status: cubit.query.status,
    );
    final applied = await showAppSheet<_QuizFilters>(
      context,
      title: 'Filters',
      builder: (context) => _FilterSheet(draft: _filterDraft, courses: courses),
    );
    if (applied == null || !mounted) return;

    // One request for both, rather than one per setter.
    await _apply(
      () => cubit.setFilters(courseId: applied.courseId, status: applied.status),
    );
  }

  /// Opens a quiz, then reloads — an attempt started or submitted in there
  /// changes the card that was just tapped.
  Future<void> _open(QuizzesCubit cubit, StudentAssessment quiz) async {
    await context.push(StudentRoutes.quizDetail(quiz.id));
    if (mounted) await cubit.load(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<QuizzesCubit>();
    final glassInsets = context.glassContentInsets;
    final hasFilters = cubit.query.hasFilters;

    return ShellScaffold(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: AppSearchField(
                    hint: 'Search quizzes',
                    onChanged: (value) => _apply(() => cubit.setSearch(value)),
                  ),
                ),
                const SizedBox(width: 8),
                _FilterButton(
                  activeCount: cubit.query.activeFilterCount,
                  onPressed: () => _openFilters(cubit),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => cubit.load(refresh: true),
              child: InfiniteScroll(
                onLoadMore: cubit.loadMore,
                child: RemoteView<QuizzesCubit, Paginated<StudentAssessment>>(
                  onRetry: cubit.load,
                  loading: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: AppListSkeleton(rows: 4),
                  ),
                  isEmpty: (page) => page.items.isEmpty,
                  // A filtered-empty list is a different problem from an empty
                  // one, and only one of them is the student's to fix.
                  emptyTitle: hasFilters
                      ? 'No quizzes match your filters'
                      : 'No quizzes yet',
                  emptyDescription: hasFilters
                      ? 'Try adjusting your search or filters.'
                      : 'Quizzes published across your enrolled courses will '
                          'appear here.',
                  emptyIcon: Icons.checklist_rounded,
                  builder: (context, page) => ListView.separated(
                    // No controller: the list must stay on the
                    // PrimaryScrollController so it coordinates with the
                    // shell's collapsing header.
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      16,
                      4,
                      16,
                      24 + glassInsets.bottom,
                    ),
                    itemCount: page.items.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index == page.items.length) {
                        return AppLoadMoreFooter(
                          isLoading: cubit.isLoadingMore || cubit.hasMore,
                          hasMore: cubit.hasMore,
                          endLabel: 'No more quizzes',
                        );
                      }
                      final quiz = page.items[index];
                      return _QuizCard(
                        quiz: quiz,
                        onTap: () => _open(cubit, quiz),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
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

/// The two filters the sheet can change, as one value so they can be staged and
/// applied atomically.
@immutable
class _QuizFilters {
  const _QuizFilters({this.courseId, this.status});

  final String? courseId;
  final String? status;

  int get activeCount => (courseId != null ? 1 : 0) + (status != null ? 1 : 0);
}

/// Course and status, as two inset-grouped checkmark lists — the same sheet the
/// Practice filters use.
class _FilterSheet extends StatelessWidget {
  const _FilterSheet({required this.draft, required this.courses});

  final ValueNotifier<_QuizFilters> draft;
  final List<AssessmentCourseRef> courses;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_QuizFilters>(
      valueListenable: draft,
      builder: (context, value, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (courses.isNotEmpty)
            AppOptionGroup<String?>(
              header: 'Course',
              selected: value.courseId,
              onSelected: (courseId) => draft.value =
                  _QuizFilters(courseId: courseId, status: value.status),
              options: [
                const AppOptionItem(
                  value: null,
                  label: 'All courses',
                  icon: Icons.apps_rounded,
                ),
                for (final course in courses)
                  AppOptionItem(
                    value: course.id,
                    label: course.name,
                    description: course.code.isEmpty ? null : course.code,
                    icon: Icons.menu_book_outlined,
                  ),
              ],
            ),
          AppOptionGroup<String?>(
            header: 'Status',
            selected: value.status,
            onSelected: (status) => draft.value =
                _QuizFilters(courseId: value.courseId, status: status),
            options: const [
              AppOptionItem(
                value: null,
                label: 'All statuses',
                icon: Icons.apps_rounded,
              ),
              AppOptionItem(
                value: AssessmentStatus.notStarted,
                label: 'Not started',
                icon: Icons.radio_button_unchecked_rounded,
              ),
              AppOptionItem(
                value: AssessmentStatus.inProgress,
                label: 'In progress',
                icon: Icons.timelapse_rounded,
              ),
              AppOptionItem(
                value: AssessmentStatus.submitted,
                label: 'Submitted',
                icon: Icons.outbox_rounded,
              ),
              AppOptionItem(
                value: AssessmentStatus.evaluated,
                label: 'Evaluated',
                icon: Icons.verified_outlined,
              ),
            ],
          ),
          AppFilterActions(
            // Disabled at defaults, so the button never implies there is
            // something to clear when there is not.
            onReset: value.activeCount == 0
                ? null
                : () => draft.value = const _QuizFilters(),
            onApply: () => Navigator.of(context).pop(value),
          ),
        ],
      ),
    );
  }
}

/// One quiz — the port of the web list's card.
class _QuizCard extends StatelessWidget {
  const _QuizCard({required this.quiz, required this.onTap});

  final StudentAssessment quiz;
  final VoidCallback onTap;

  /// Status colours, matching the web's `STATUS_META`.
  static (TwShade, IconData) _statusMeta(String status) => switch (status) {
        AssessmentStatus.inProgress => (TwColors.amber, Icons.timer_outlined),
        AssessmentStatus.submitted => (TwColors.blue, Icons.send_rounded),
        AssessmentStatus.evaluated => (TwColors.emerald, Icons.verified_rounded),
        _ => (TwColors.slate, Icons.schedule_rounded),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final now = DateTime.now();

    final (shade, icon) = _statusMeta(quiz.statusKey);
    final closed = quiz.submission == null && quiz.isWindowClosed(now);
    // `outcomeText` covers everything the student has already done; the two
    // remaining cases are the ones where there is nothing to report yet.
    final outcome = quiz.outcomeText().isNotEmpty
        ? quiz.outcomeText()
        : (closed ? 'Due date passed' : 'Tap to start');

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  quiz.title,
                  style: theme.textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              AppBadge(
                AssessmentStatus.label(quiz.statusKey),
                shade: shade,
                icon: icon,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (quiz.course != null) ...[
                _CourseChip(course: quiz.course!),
                const SizedBox(width: 8),
              ],
              if (quiz.creator != null)
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        size: 13,
                        color: scheme.mutedForeground,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          quiz.creator!.name,
                          style: theme.textTheme.labelSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _Meta(
                icon: Icons.schedule_rounded,
                label: 'Starts ${Fmt.dateTime(quiz.startDate)}',
              ),
              _Meta(
                icon: Icons.event_rounded,
                label: 'Due ${Fmt.dateTime(quiz.endDate)}',
              ),
              _Meta(
                icon: Icons.workspace_premium_outlined,
                label: '${quiz.totalMarks} marks',
              ),
              if (quiz.isProctored)
                const _Meta(
                  icon: Icons.visibility_outlined,
                  label: 'Proctored',
                ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, thickness: 1, color: scheme.border),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  outcome,
                  style: theme.textTheme.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                quiz.actionText(now),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: scheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The course-code chip, tinted with the course's own colour.
class _CourseChip extends StatelessWidget {
  const _CourseChip({required this.course});

  final AssessmentCourseRef course;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    // A teacher-set colour that never parses just yields the neutral chip.
    final tint = parseHexColor(course.colorCode);
    final code = course.code.isEmpty ? '—' : course.code;

    if (tint == null) {
      return AppBadge(code, dense: true);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Text(
        code,
        style: TextStyle(
          color: Color.alphaBlend(tint.withValues(alpha: 0.92), scheme.foreground),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontFamily: AppTheme.mono,
        ),
      ),
    );
  }
}

/// One `icon + label` pair in the card's meta row.
class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: scheme.mutedForeground),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
