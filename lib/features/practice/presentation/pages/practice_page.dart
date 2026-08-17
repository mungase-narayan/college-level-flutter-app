import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../../../core/design/extensions/glass_context.dart';
import '../../../../core/network/api_response.dart';
import '../../../shell/presentation/pages/student_shell.dart';
import '../../../shell/presentation/widgets/student_nav.dart';
import '../../domain/entities/practice_question.dart';
import '../../domain/usecases/practice_usecases.dart';
import '../bloc/practice_list_cubit.dart';

/// Port of `src/pages/student/practice/index.tsx` — the practice question bank.
///
/// The desktop filter bar (search, type, difficulty, course, attempt status,
/// bookmarked) becomes a search field plus chip rows, and the paginator becomes
/// infinite scroll.
class PracticePage extends StatefulWidget {
  const PracticePage({super.key});

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  /// What the open filter sheet has staged so far.
  ///
  /// Owned by the page rather than by the sheet because the sheet's header
  /// actions need it too, and they are siblings of the sheet's body rather than
  /// descendants of it. Kept for the page's lifetime instead of one per opening,
  /// so it is never disposed while the sheet is still animating out.
  final _filterDraft = ValueNotifier(
    const _PracticeFilters(sort: _PracticeFilters.defaultSort),
  );

  @override
  void initState() {
    super.initState();
    context.read<PracticeListCubit>().load();
  }

  @override
  void dispose() {
    _filterDraft.dispose();
    super.dispose();
  }

  /// Opens the filter sheet and commits the result.
  ///
  /// The two chip rows used to sit permanently above the list, costing ~80pt of a
  /// phone screen to show options that are mostly left at their defaults. Behind a
  /// button they cost nothing until asked for, and the badge keeps the current
  /// state visible.
  Future<void> _openFilters(PracticeListCubit cubit) async {
    // Fetched here rather than on page load: only the sheet needs the course
    // list, and most visits never open it.
    final courses = await cubit.courseOptions();
    if (!mounted) return;

    // Each opening starts from what is actually applied, so a sheet that was
    // dismissed without applying leaves nothing behind.
    _filterDraft.value = _PracticeFilters.from(cubit.query);
    final applied = await showAppSheet<_PracticeFilters>(
      context,
      title: 'Filters',
      builder: (context) => _FilterSheet(draft: _filterDraft, courses: courses),
    );
    if (applied == null || !mounted) return;

    // One request for every filter, rather than one per setter.
    await cubit.setFilters(
      type: applied.type,
      courseId: applied.courseId,
      bookmarked: applied.bookmarked,
      sort: applied.sort,
      attemptStatus: applied.attemptStatus,
      difficulty: applied.difficulty,
    );
    // Refreshes the badge; the query is not part of the cubit's emitted state.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PracticeListCubit>();
    final glassInsets = context.glassContentInsets;

    // The shell owns the app bar; this contributes body only.
    return StudentScaffold(
      child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: AppSearchField(
                      hint: 'Search questions',
                      onChanged: cubit.setSearch,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _FilterButton(
                    activeCount: _PracticeFilters.from(cubit.query).activeCount,
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
                  child: RemoteView<PracticeListCubit,
                      Paginated<PracticeQuestionListItem>>(
                    onRetry: cubit.load,
                    loading: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: AppListSkeleton(rows: 5),
                    ),
                    isEmpty: (page) => page.items.isEmpty,
                    emptyTitle: 'No questions found',
                    emptyDescription:
                        'Try clearing a filter, or check back once your school '
                        'publishes more practice questions.',
                    emptyIcon: Icons.extension_outlined,
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
                          );
                        }
                        final question = page.items[index];
                        return _QuestionCard(
                          question: question,
                          onToggleBookmark: () => cubit.toggleBookmark(question),
                          // Opens the solve workspace, then reloads: an attempt
                          // made in there changes this card's status line.
                          onTap: () async {
                            await context
                                .push(StudentRoutes.practiceQuestion(question.id));
                            if (context.mounted) {
                              await cubit.load(refresh: true);
                            }
                          },
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

/// The filters the sheet can change, as one value so it can be staged and applied
/// atomically.
@immutable
class _PracticeFilters {
  const _PracticeFilters({
    required this.sort,
    this.attemptStatus,
    this.difficulty,
    this.type,
    this.courseId,
    this.bookmarked = false,
  });

  factory _PracticeFilters.from(PracticeQueryParams query) => _PracticeFilters(
        sort: query.sort,
        attemptStatus: query.attemptStatus,
        difficulty: query.difficulty,
        type: query.type,
        courseId: query.courseId,
        bookmarked: query.bookmarked == true,
      );

  final String sort;
  final String? attemptStatus;
  final String? difficulty;
  final String? type;
  final String? courseId;

  /// One-way, like the web's: the endpoint has no "not bookmarked" mode.
  final bool bookmarked;

  static const defaultSort = 'recent';

  /// How many filters differ from their default — the number on the badge.
  int get activeCount =>
      (sort != defaultSort ? 1 : 0) +
      (attemptStatus != null ? 1 : 0) +
      (difficulty != null ? 1 : 0) +
      (type != null ? 1 : 0) +
      (courseId != null ? 1 : 0) +
      (bookmarked ? 1 : 0);

  _PracticeFilters copyWith({
    String? sort,
    String? attemptStatus,
    String? difficulty,
    String? type,
    String? courseId,
    bool? bookmarked,
    bool clearAttemptStatus = false,
    bool clearDifficulty = false,
    bool clearType = false,
    bool clearCourse = false,
  }) =>
      _PracticeFilters(
        sort: sort ?? this.sort,
        attemptStatus:
            clearAttemptStatus ? null : (attemptStatus ?? this.attemptStatus),
        difficulty: clearDifficulty ? null : (difficulty ?? this.difficulty),
        type: clearType ? null : (type ?? this.type),
        courseId: clearCourse ? null : (courseId ?? this.courseId),
        bookmarked: bookmarked ?? this.bookmarked,
      );
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

/// Sort, status and difficulty in one sheet.
///
/// Selections are staged in [draft] and committed by the sheet header's Apply
/// action, so a request is not sent per tap while the sheet is open and the user
/// can back out — with Cancel, a swipe down, or a tap outside — with no side
/// effects.
///
/// Laid out as three inset-grouped checkmark lists rather than as rows of pill
/// chips. Each of these filters is a pick-one, which is what a checkmark list
/// says and a row of chips does not: chips read as independent toggles, and
/// wrapping them into ragged lines made the three groups hard to tell apart at a
/// glance.
class _FilterSheet extends StatelessWidget {
  const _FilterSheet({required this.draft, required this.courses});

  final ValueNotifier<_PracticeFilters> draft;

  /// Empty when the filter endpoint could not be reached — the group is then
  /// hidden rather than shown with nothing in it.
  final List<PracticeSubject> courses;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_PracticeFilters>(
      valueListenable: draft,
      builder: (context, value, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppOptionGroup<String>(
            header: 'Sort by',
            selected: value.sort,
            onSelected: (sort) => draft.value = value.copyWith(sort: sort),
            options: const [
              AppOptionItem(
                value: 'recent',
                label: 'Most recent',
                icon: Icons.schedule_rounded,
              ),
              AppOptionItem(
                value: 'popular',
                label: 'Most attempted',
                icon: Icons.local_fire_department_outlined,
              ),
              AppOptionItem(
                value: 'difficulty',
                label: 'Difficulty',
                icon: Icons.signal_cellular_alt_rounded,
              ),
            ],
          ),
          AppOptionGroup<String?>(
            header: 'Status',
            selected: value.attemptStatus,
            onSelected: (status) => draft.value = value.copyWith(
              attemptStatus: status,
              clearAttemptStatus: status == null,
            ),
            options: const [
              AppOptionItem(
                value: null,
                label: 'All questions',
                icon: Icons.apps_rounded,
              ),
              AppOptionItem(
                value: 'not_attempted',
                label: 'Unattempted',
                icon: Icons.radio_button_unchecked_rounded,
              ),
              AppOptionItem(
                value: 'solved',
                label: 'Solved',
                icon: Icons.check_circle_outline_rounded,
              ),
              AppOptionItem(
                value: 'incorrect',
                label: 'Incorrect',
                icon: Icons.cancel_outlined,
              ),
            ],
          ),
          AppOptionGroup<String?>(
            header: 'Difficulty',
            selected: value.difficulty,
            onSelected: (difficulty) => draft.value = value.copyWith(
              difficulty: difficulty,
              clearDifficulty: difficulty == null,
            ),
            options: const [
              AppOptionItem(
                value: null,
                label: 'Any difficulty',
                icon: Icons.apps_rounded,
              ),
              AppOptionItem(
                value: 'easy',
                label: 'Easy',
                icon: Icons.sentiment_satisfied_outlined,
              ),
              AppOptionItem(
                value: 'medium',
                label: 'Medium',
                icon: Icons.sentiment_neutral_outlined,
              ),
              AppOptionItem(
                value: 'hard',
                label: 'Hard',
                icon: Icons.whatshot_outlined,
              ),
            ],
          ),
          AppOptionGroup<String?>(
            header: 'Type',
            selected: value.type,
            onSelected: (type) => draft.value = value.copyWith(
              type: type,
              clearType: type == null,
            ),
            options: const [
              AppOptionItem(
                value: null,
                label: 'Any type',
                icon: Icons.apps_rounded,
              ),
              AppOptionItem(
                value: 'mcq',
                label: 'MCQ',
                icon: Icons.checklist_rounded,
              ),
              AppOptionItem(
                value: 'true_false',
                label: 'True / False',
                icon: Icons.toggle_on_outlined,
              ),
              AppOptionItem(
                value: 'subjective',
                label: 'Subjective',
                icon: Icons.notes_rounded,
              ),
              AppOptionItem(
                value: 'coding',
                label: 'Coding',
                icon: Icons.code_rounded,
              ),
            ],
          ),
          if (courses.isNotEmpty)
            AppOptionGroup<String?>(
              header: 'Course',
              selected: value.courseId,
              onSelected: (courseId) => draft.value = value.copyWith(
                courseId: courseId,
                clearCourse: courseId == null,
              ),
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
                  ),
              ],
            ),
          AppOptionGroup<bool>(
            header: 'Saved',
            selected: value.bookmarked,
            onSelected: (bookmarked) =>
                draft.value = value.copyWith(bookmarked: bookmarked),
            options: const [
              AppOptionItem(
                value: false,
                label: 'All questions',
                icon: Icons.apps_rounded,
              ),
              AppOptionItem(
                value: true,
                label: 'Bookmarked only',
                icon: Icons.bookmark_outline_rounded,
              ),
            ],
          ),
          AppFilterActions(
            // Disabled at defaults, so the button never implies there is
            // something to clear when there is not.
            onReset: value.activeCount == 0
                ? null
                : () => draft.value = const _PracticeFilters(
                      sort: _PracticeFilters.defaultSort,
                    ),
            onApply: () => Navigator.of(context).pop(value),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.onToggleBookmark,
    required this.onTap,
  });

  final PracticeQuestionListItem question;
  final VoidCallback onToggleBookmark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final scheme = tokens.scheme;

    // Difficulty uses its own scale: teal / amber / red.
    final difficultyShade = switch (question.difficulty) {
      'easy' => TwColors.teal,
      'hard' => TwColors.red,
      _ => TwColors.amber,
    };

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (question.stats.isSolved)
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 2),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 17,
                    color: tokens.success.foreground,
                  ),
                ),
              Expanded(
                child: Text(
                  question.title,
                  style: theme.textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: onToggleBookmark,
                visualDensity: VisualDensity.compact,
                tooltip: question.bookmarked ? 'Remove bookmark' : 'Bookmark',
                icon: Icon(
                  question.bookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: 19,
                  color: question.bookmarked ? scheme.primary : scheme.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              AppBadge(
                question.difficulty[0].toUpperCase() + question.difficulty.substring(1),
                shade: difficultyShade,
                dense: true,
              ),
              AppBadge(question.typeLabel, dense: true),
              AppBadge('${question.points} pts', dense: true),
              if (question.stats.pendingReview)
                AppBadge('Awaiting review', shade: TwColors.amber, dense: true),
            ],
          ),
          if ((question.subject ?? '').isNotEmpty ||
              (question.topicName ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              [question.subject, question.moduleName, question.topicName]
                  .where((part) => (part ?? '').isNotEmpty)
                  .join(' · '),
              style: theme.textTheme.labelSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (question.stats.attempts > 0) ...[
            const SizedBox(height: 8),
            Text(
              '${question.stats.attempts} attempt'
              '${question.stats.attempts == 1 ? '' : 's'}'
              '${question.stats.accuracy == null ? '' : ' · ${question.stats.accuracy}% accuracy'}',
              style: theme.textTheme.labelSmall,
            ),
          ],
        ],
      ),
    );
  }
}
