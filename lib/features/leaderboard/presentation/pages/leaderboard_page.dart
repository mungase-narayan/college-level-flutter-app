import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/common/bloc/remote_cubit.dart';
import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../../../core/design/animations/glass_curves.dart';
import '../../../../core/design/extensions/glass_context.dart';
import '../../../shell/presentation/pages/student_shell.dart';
import '../../domain/entities/leaderboard.dart';
import '../../domain/usecases/leaderboard_usecases.dart';
import '../bloc/leaderboard_cubit.dart';
import '../widgets/leaderboard_row_card.dart';
import '../widgets/leaderboard_toolbar.dart';
import '../widgets/my_rank_banner.dart';
import '../widgets/podium.dart';

/// Port of `src/pages/student/practice/leaderboard.tsx`.
///
/// Scope and period pickers, the student's own standing, a podium for the top
/// three on page 1, then the rest as rows. Paging is by number, matching the
/// web's page controls, so a new page replaces the rows rather than appending.
class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  @override
  void initState() {
    super.initState();
    context.read<LeaderboardCubit>().load();
  }

  /// Opens the student's public showcase in-app.
  ///
  /// The web opens `/@username` in a new browser tab; here the same path is a
  /// real screen pushed over the shell, so the reader keeps their place on the
  /// board and comes straight back with the system back gesture.
  void _openProfile(LeaderboardRow row) {
    final username = row.username;
    if (username == null || username.isEmpty) return;
    context.push('/@${Uri.encodeComponent(username)}');
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LeaderboardCubit>();

    return StudentScaffold(
      child: BlocBuilder<LeaderboardCubit, RemoteState<LeaderboardStandings>>(
        builder: (context, state) {
          final params = cubit.params;
          final page = state.data;
          final isFetching = state.isLoading && page != null;

          return Column(
            children: [
              LeaderboardToolbar(
                scope: params.scope,
                period: params.period,
                onScopeChanged: cubit.setScope,
                onPeriodChanged: cubit.setPeriod,
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => cubit.load(refresh: true),
                  // The web dims the list while a new page is in flight rather
                  // than swapping in a spinner.
                  child: AnimatedOpacity(
                    opacity: isFetching ? 0.6 : 1,
                    duration: context.glass.duration(GlassDurations.fast),
                    child: _Body(
                      state: state,
                      params: params,
                      onRetry: cubit.load,
                      onPageChanged: cubit.setPage,
                      onOpenProfile: _openProfile,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    required this.params,
    required this.onRetry,
    required this.onPageChanged,
    required this.onOpenProfile,
  });

  final RemoteState<LeaderboardStandings> state;
  final LeaderboardParams params;
  final VoidCallback onRetry;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<LeaderboardRow> onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final page = state.data;
    final glassInsets = context.glassContentInsets;

    if (state.isInitialLoading) return const _Skeleton();

    if (page == null) {
      return state.failure != null
          ? AppErrorView(failure: state.failure!, onRetry: onRetry)
          : const AppEmptyState(
              icon: Icons.leaderboard_outlined,
              title: 'No rankings yet',
              description: 'Solve practice questions to climb the leaderboard.',
            );
    }

    final me = page.me;
    // The podium only makes sense on the first page, where ranks 1-3 actually
    // are the top three.
    final showPodium = page.pagination.page == 1 && page.rows.isNotEmpty;
    final podiumRows = showPodium ? page.rows.take(3).toList() : const <LeaderboardRow>[];
    final listRows = showPodium ? page.rows.skip(3).toList() : page.rows;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: 24 + glassInsets.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Outside the switcher below: the student's own standing should not
          // flicker every time they change scope.
          if (me != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: MyRankBanner(
                me: me,
                scope: page.scope,
                period: page.period,
              ),
            ),

          if (page.rows.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: AppEmptyState(
                icon: Icons.leaderboard_outlined,
                title: 'No rankings yet',
                description: 'Solve practice questions to climb the leaderboard.',
              ),
            )
          else
            // Keyed on the query so a scope, period or page change cross-fades
            // instead of the rows swapping under the reader's eyes.
            AnimatedSwitcher(
              duration: glass.duration(GlassDurations.fast),
              switchInCurve: glass.curve(GlassCurves.easeOutSmooth),
              child: Column(
                key: ValueKey(
                  '${page.scope}-${page.period}-${page.pagination.page}',
                ),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (podiumRows.isNotEmpty) ...[
                    Podium(rows: podiumRows, onTap: onOpenProfile),
                    const SizedBox(height: 14),
                  ],
                  for (var i = 0; i < listRows.length; i++)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: StaggeredEntrance(
                        // Continue the stagger past the podium so the whole
                        // page reads as one arrival.
                        index: i + podiumRows.length,
                        child: LeaderboardRowCard(
                          row: listRows[i],
                          onTap: listRows[i].username == null
                              ? null
                              : () => onOpenProfile(listRows[i]),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // Hides itself when there is only one page, matching the web.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppPaginator(
              pagination: page.pagination,
              onPageChanged: onPageChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, index) => AppSkeleton(
          height: index == 0 ? 116 : 60,
          radius: AppTheme.radiusLg,
        ),
      );
}
