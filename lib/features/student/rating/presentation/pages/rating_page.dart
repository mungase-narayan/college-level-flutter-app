import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/design/animations/glass_curves.dart';
import '../../../../../core/design/extensions/glass_context.dart';
import '../../../../shared/shell/presentation/pages/app_shell.dart';
import '../../../../shared/shell/presentation/widgets/student_nav.dart';
import '../../domain/entities/contest_rating.dart';
import '../bloc/rating_cubit.dart';
import '../bloc/rating_leaderboard_cubit.dart';
import '../widgets/rating_chart.dart';
import '../widgets/rating_history_row.dart';
import '../widgets/rating_leaderboard_row.dart';
import '../widgets/rating_stat_tiles.dart';

/// Which list sits below the curve.
enum RatingTab { history, leaderboard }

/// Port of `src/pages/student/contests/rating.tsx`.
///
/// The student's own standing on top — tiles and the rating curve — then either
/// their contest history or the school's rated standings.
class RatingPage extends StatefulWidget {
  const RatingPage({super.key});

  @override
  State<RatingPage> createState() => _RatingPageState();
}

class _RatingPageState extends State<RatingPage> {
  RatingTab _tab = RatingTab.history;

  @override
  void initState() {
    super.initState();
    context.read<RatingCubit>().load();
    context.read<RatingLeaderboardCubit>().load();
  }

  Future<void> _refresh() => Future.wait([
        context.read<RatingCubit>().load(refresh: true),
        context.read<RatingLeaderboardCubit>().load(refresh: true),
      ]);

  void _openTab(RatingTab tab) {
    if (tab != _tab) setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    return ShellScaffold(
      child: BlocBuilder<RatingCubit, RemoteState<ContestRating>>(
        builder: (context, state) {
          if (state.isInitialLoading) return const _Skeleton();

          final rating = state.data;
          if (rating == null) {
            return AppErrorView(
              failure: state.failure!,
              onRetry: context.read<RatingCubit>().load,
            );
          }

          return RefreshableScroll(
            onRefresh: _refresh,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BlocBuilder<RatingLeaderboardCubit,
                    RemoteState<RatingLeaderboard>>(
                  builder: (context, boardState) {
                    final board = boardState.data;
                    return StaggeredEntrance(
                      index: 0,
                      child: RatingStatTiles(
                        rating: rating,
                        // Sourced from the leaderboard, but rendered up here
                        // with the other headline numbers.
                        myRank: board?.myRank,
                        ratedTotal: board?.pagination.total,
                      ),
                    );
                  },
                ),

                if (rating.isProvisional) ...[
                  const SizedBox(height: 10),
                  const _ProvisionalNote(),
                ],

                const SizedBox(height: 12),
                StaggeredEntrance(
                  index: 1,
                  child: _CurveCard(history: rating.history),
                ),

                const SizedBox(height: 14),
                _TabBar(selected: _tab, onChanged: _openTab),
                const SizedBox(height: 12),

                AnimatedSwitcher(
                  duration: context.glass.duration(GlassDurations.fast),
                  switchInCurve:
                      context.glass.curve(GlassCurves.easeOutSmooth),
                  child: _tab == RatingTab.history
                      ? _HistoryList(
                          key: const ValueKey('history'),
                          history: rating.history,
                        )
                      : const _LeaderboardList(key: ValueKey('leaderboard')),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProvisionalNote extends StatelessWidget {
  const _ProvisionalNote();

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.muted,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: scheme.border),
      ),
      child: Text(
        "You haven't competed in a rated contest yet — this is the starting "
        'rating everyone begins with.',
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class _CurveCard extends StatelessWidget {
  const _CurveCard({required this.history});

  final List<RatingHistoryEntry> history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rated = history.length;

    return AppSectionCard(
      title: 'Rating over time',
      icon: Icons.show_chart_rounded,
      trailing: rated == 0
          ? null
          : Text(
              '$rated rated contest${rated == 1 ? '' : 's'}',
              style: theme.textTheme.labelSmall,
            ),
      child: history.isEmpty
          ? SizedBox(
              height: RatingChart.height,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.show_chart_rounded,
                      size: 26,
                      color: context.scheme.mutedForeground
                          .withValues(alpha: 0.45),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No rated contests yet',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: context.scheme.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Take part in a rated contest and your rating curve '
                        'starts here.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.only(top: 8, right: 6),
              child: RatingChart(history: history),
            ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.selected, required this.onChanged});

  final RatingTab selected;
  final ValueChanged<RatingTab> onChanged;

  @override
  Widget build(BuildContext context) => AppFilterChips<RatingTab>(
        selected: selected,
        onSelected: onChanged,
        wrap: true,
        options: const [
          AppFilterChipOption(value: RatingTab.history, label: 'History'),
          AppFilterChipOption(
            value: RatingTab.leaderboard,
            label: 'School leaderboard',
          ),
        ],
      );
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({super.key, required this.history});

  final List<RatingHistoryEntry> history;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const AppEmptyState(
        icon: Icons.history_rounded,
        title: 'Your contest history will appear here.',
      );
    }

    // The API returns oldest first; the most recent contest is the one worth
    // reading, so it leads.
    final newestFirst = history.reversed.toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < newestFirst.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == newestFirst.length - 1 ? 0 : 10,
            ),
            child: StaggeredEntrance(
              index: i,
              child: RatingHistoryRow(
                entry: newestFirst[i],
                // The standings screen does not exist yet; the Contests tab is
                // where it will live, so the gesture is already pointed at it.
                onTap: () => context.push(StudentRoutes.contests),
              ),
            ),
          ),
      ],
    );
  }
}

class _LeaderboardList extends StatelessWidget {
  const _LeaderboardList({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RatingLeaderboardCubit>();

    return BlocBuilder<RatingLeaderboardCubit, RemoteState<RatingLeaderboard>>(
      builder: (context, state) {
        if (state.isInitialLoading) {
          return const AppListSkeleton(rows: 4, lines: 2);
        }

        final board = state.data;
        if (board == null) {
          return AppErrorView(failure: state.failure!, onRetry: cubit.load);
        }
        if (board.entries.isEmpty) {
          return const AppEmptyState(
            icon: Icons.emoji_events_outlined,
            title: 'Nobody is rated yet',
          );
        }

        return AnimatedOpacity(
          opacity: state.isLoading ? 0.6 : 1,
          duration: context.glass.duration(GlassDurations.fast),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < board.entries.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == board.entries.length - 1 ? 0 : 10,
                  ),
                  child: StaggeredEntrance(
                    index: i,
                    child: RatingLeaderboardRow(
                      entry: board.entries[i],
                      onTap: board.entries[i].username.isEmpty
                          ? null
                          : () => context.push(
                                '/@${Uri.encodeComponent(board.entries[i].username)}',
                              ),
                    ),
                  ),
                ),
              // Hides itself at a single page.
              AppPaginator(
                pagination: board.pagination,
                onPageChanged: cubit.setPage,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: const [
          AppSkeleton(height: 96, radius: AppTheme.radiusLg),
          SizedBox(height: 10),
          AppSkeleton(height: 96, radius: AppTheme.radiusLg),
          SizedBox(height: 12),
          AppSkeleton(height: 240, radius: AppTheme.radiusLg),
        ],
      );
}
