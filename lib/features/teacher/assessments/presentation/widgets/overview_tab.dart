import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_colors.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../domain/entities/submission.dart';
import '../bloc/overview_cubit.dart';

/// Port of `overview-matrix.tsx`.
///
/// The web renders a table on a wide screen and a card list on a narrow one;
/// only the card list applies here. Its per-question `results` matrix is
/// fetched and never rendered on the web either, so it is not shown.
class OverviewTab extends StatefulWidget {
  const OverviewTab({super.key, required this.onOpenSubmission});

  final ValueChanged<SubmissionRow> onOpenSubmission;

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  @override
  void initState() {
    super.initState();
    context.read<OverviewCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OverviewCubit>();

    return RefreshIndicator(
      onRefresh: () => cubit.load(refresh: true),
      child: BlocBuilder<OverviewCubit, RemoteState<AssignmentOverview>>(
        builder: (context, state) {
          final overview = state.data;
          final failure = state.failure;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _Summary(overview: overview),
              const SizedBox(height: 12),
              AppSearchField(
                dense: true,
                hint: 'Search by name or roll number',
                onChanged: cubit.setSearch,
              ),
              const SizedBox(height: 10),
              AppSelect<String>(
                dense: true,
                value: cubit.sort,
                items: [
                  for (final option in OverviewCubit.sortOptions)
                    AppSelectItem(
                      value: option,
                      label: OverviewCubit.sortLabel(option),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => cubit.setSort(value ?? cubit.sort)),
              ),
              const SizedBox(height: 14),
              if (state.isInitialLoading)
                const AppListSkeleton(rows: 4, lines: 2)
              else if (state.status == RemoteStatus.failure && failure != null)
                AppErrorView(failure: failure, onRetry: cubit.load)
              else if ((overview?.learners ?? const []).isEmpty)
                AppEmptyState(
                  icon: Icons.groups_outlined,
                  title: cubit.search.isEmpty
                      ? 'No attempts yet'
                      : 'No matching learners',
                  description: cubit.search.isEmpty
                      ? 'Attempts appear here as students start and submit.'
                      : 'Try a different name or roll number.',
                )
              else ...[
                for (var i = 0; i < overview!.learners.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  StaggeredEntrance(
                    index: i,
                    child: _LearnerCard(
                      learner: overview.learners[i],
                      onTap: () =>
                          widget.onOpenSubmission(overview.learners[i]),
                    ),
                  ),
                ],
                if (overview.totalPages > 1)
                  _Pager(
                    page: overview.page,
                    totalPages: overview.totalPages,
                    onChanged: cubit.setPage,
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.overview});

  final AssignmentOverview? overview;

  @override
  Widget build(BuildContext context) {
    // A dash until the payload lands — zero would read as a real count.
    final avg = overview?.avgPercent;

    return AppStatGrid(
      columns: 3,
      tiles: [
        AppStatTile(
          label: 'Submissions',
          value: overview == null ? '—' : '${overview!.total}',
          icon: Icons.groups_outlined,
        ),
        AppStatTile(
          label: 'Evaluated',
          value: overview == null
              ? '—'
              : '${overview!.evaluated}/${overview!.total}',
          icon: Icons.verified_outlined,
          shade: TwColors.emerald,
        ),
        AppStatTile(
          label: 'Average',
          value: avg == null ? '—' : '$avg%',
          icon: Icons.track_changes_outlined,
        ),
      ],
    );
  }
}

class _LearnerCard extends StatelessWidget {
  const _LearnerCard({required this.learner, required this.onTap});

  final SubmissionRow learner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final fraction = learner.fraction;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              AppAvatar(
                imageUrl: learner.avatar,
                name: learner.fullName,
                size: 34,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      learner.fullName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.foreground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (learner.identifier.isNotEmpty)
                      Text(
                        learner.identifier,
                        style: theme.textTheme.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: scheme.mutedForeground,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: scheme.border)),
            ),
            child: Row(
              children: [
                AppBadge(
                  SubmissionStatus.label(learner.status),
                  shade: SubmissionStatus.shade(learner.status),
                  dense: true,
                ),
                const Spacer(),
                if (fraction == null)
                  Text('—', style: theme.textTheme.labelSmall)
                else
                  AppBadge(
                    '${learner.totalScore ?? 0}/${learner.maxScore}',
                    // Half marks is the web's pass line for the pill colour,
                    // independent of the assessment's own pass mark.
                    shade: fraction >= 0.5 ? TwColors.emerald : TwColors.rose,
                    dense: true,
                  ),
                const SizedBox(width: 10),
                Text(
                  Fmt.duration(learner.timeSpentSeconds),
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.page,
    required this.totalPages,
    required this.onChanged,
  });

  final int page;
  final int totalPages;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: page > 1 ? () => onChanged(page - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Text(
            'Page $page of $totalPages',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          IconButton(
            onPressed: page < totalPages ? () => onChanged(page + 1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}
