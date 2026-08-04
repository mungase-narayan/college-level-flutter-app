import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../../../core/design/extensions/glass_context.dart';
import '../../../../core/network/api_response.dart';
import '../../../shell/presentation/pages/student_shell.dart';
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
  @override
  void initState() {
    super.initState();
    context.read<PracticeListCubit>().load();
  }

  /// Opens the filter sheet and commits the result.
  ///
  /// The two chip rows used to sit permanently above the list, costing ~80pt of a
  /// phone screen to show options that are mostly left at their defaults. Behind a
  /// button they cost nothing until asked for, and the badge keeps the current
  /// state visible.
  Future<void> _openFilters(PracticeListCubit cubit) async {
    final applied = await showAppSheet<_PracticeFilters>(
      context,
      title: 'Filters',
      builder: (context) => _FilterSheet(
        initial: _PracticeFilters.from(cubit.query),
      ),
    );
    if (applied == null || !mounted) return;

    // One request for all three, rather than one per setter.
    await cubit.setFilters(
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
                        return _QuestionCard(
                          question: page.items[index],
                          onToggleBookmark: () =>
                              cubit.toggleBookmark(page.items[index]),
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
  });

  factory _PracticeFilters.from(PracticeQueryParams query) => _PracticeFilters(
        sort: query.sort,
        attemptStatus: query.attemptStatus,
        difficulty: query.difficulty,
      );

  final String sort;
  final String? attemptStatus;
  final String? difficulty;

  static const defaultSort = 'recent';

  /// How many filters differ from their default — the number on the badge.
  int get activeCount =>
      (sort != defaultSort ? 1 : 0) +
      (attemptStatus != null ? 1 : 0) +
      (difficulty != null ? 1 : 0);

  _PracticeFilters copyWith({
    String? sort,
    String? attemptStatus,
    String? difficulty,
    bool clearAttemptStatus = false,
    bool clearDifficulty = false,
  }) =>
      _PracticeFilters(
        sort: sort ?? this.sort,
        attemptStatus:
            clearAttemptStatus ? null : (attemptStatus ?? this.attemptStatus),
        difficulty: clearDifficulty ? null : (difficulty ?? this.difficulty),
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
/// Selections are staged locally and committed on Apply, so a request is not sent
/// per tap while the sheet is open and the user can back out with no side effects.
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});

  final _PracticeFilters initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late _PracticeFilters _draft = widget.initial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget section(String label, Widget chips) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium),
              const SizedBox(height: 10),
              chips,
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        section(
          'Sort by',
          AppFilterChips<String>(
            wrap: true,
            selected: _draft.sort,
            onSelected: (value) => setState(
              () => _draft = _draft.copyWith(sort: value),
            ),
            options: const [
              AppFilterChipOption(value: 'recent', label: 'Most recent'),
              AppFilterChipOption(value: 'popular', label: 'Most attempted'),
              AppFilterChipOption(value: 'difficulty', label: 'Difficulty'),
            ],
          ),
        ),
        section(
          'Status',
          AppFilterChips<String?>(
            wrap: true,
            selected: _draft.attemptStatus,
            onSelected: (value) => setState(
              () => _draft = _draft.copyWith(
                attemptStatus: value,
                clearAttemptStatus: value == null,
              ),
            ),
            options: const [
              AppFilterChipOption(value: null, label: 'All'),
              AppFilterChipOption(value: 'not_attempted', label: 'Unattempted'),
              AppFilterChipOption(value: 'solved', label: 'Solved'),
              AppFilterChipOption(value: 'incorrect', label: 'Incorrect'),
            ],
          ),
        ),
        section(
          'Difficulty',
          AppFilterChips<String?>(
            wrap: true,
            selected: _draft.difficulty,
            onSelected: (value) => setState(
              () => _draft = _draft.copyWith(
                difficulty: value,
                clearDifficulty: value == null,
              ),
            ),
            options: const [
              AppFilterChipOption(value: null, label: 'Any difficulty'),
              AppFilterChipOption(value: 'easy', label: 'Easy'),
              AppFilterChipOption(value: 'medium', label: 'Medium'),
              AppFilterChipOption(value: 'hard', label: 'Hard'),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Reset',
                variant: AppButtonVariant.outline,
                expand: true,
                // Disabled at defaults, so the button never implies there is
                // something to clear when there is not.
                onPressed: _draft.activeCount == 0
                    ? null
                    : () => setState(
                          () => _draft = const _PracticeFilters(
                            sort: _PracticeFilters.defaultSort,
                          ),
                        ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppButton(
                label: 'Apply',
                expand: true,
                onPressed: () => Navigator.of(context).pop(_draft),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.question, required this.onToggleBookmark});

  final PracticeQuestionListItem question;
  final VoidCallback onToggleBookmark;

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
      // The solve workspace is a later pass; the card is informational for now.
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
