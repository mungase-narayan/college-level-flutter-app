import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../shell/presentation/widgets/student_nav.dart';
import '../../domain/entities/public_profile.dart';
import '../bloc/public_profile_cubit.dart';
import '../widgets/public_badge_row.dart';
import '../widgets/public_profile_header.dart';
import '../widgets/recent_solved_row.dart';

/// Port of `src/pages/public/profile/index.tsx` — a student's public showcase.
///
/// The web renders this as a standalone unauthenticated page with its own
/// branded header. Here it is pushed from the leaderboard, so it takes an app
/// bar with a back button instead; everything below the chrome is the same.
class PublicProfilePage extends StatefulWidget {
  const PublicProfilePage({super.key});

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  @override
  void initState() {
    super.initState();
    context.read<PublicProfileCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PublicProfileCubit>();

    return Scaffold(
      appBar: AdaptiveAppBar(
        title: 'Profile',
        // Explicit rather than automatic: `/@username` is a public deep link, so
        // this screen can open with nothing to pop. Popping is still preferred
        // when there is a stack, which keeps the reader's place on the board.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(StudentRoutes.leaderboard),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => cubit.load(refresh: true),
        child: RemoteView<PublicProfileCubit, PublicProfile>(
          onRetry: cubit.load,
          loading: const _Skeleton(),
          builder: (context, profile) => _Content(profile: profile),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.profile});

  final PublicProfile profile;

  @override
  Widget build(BuildContext context) {
    final stats = profile.stats;

    return RefreshableScroll(
      onRefresh: () => context.read<PublicProfileCubit>().load(refresh: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StaggeredEntrance(
            index: 0,
            child: PublicProfileHeader(profile: profile),
          ),
          const SizedBox(height: 12),

          StaggeredEntrance(
            index: 1,
            child: AppStatGrid(
              tiles: [
                AppStatTile(
                  label: 'Questions solved',
                  value: '${stats.solved}',
                  icon: Icons.extension_rounded,
                  shade: TwColors.violet,
                ),
                AppStatTile(
                  label: 'Day streak',
                  value: '${stats.currentStreak}',
                  icon: Icons.local_fire_department_rounded,
                  shade: TwColors.orange,
                ),
                AppStatTile(
                  label: 'Points earned',
                  value: '${stats.points}',
                  icon: AppIcons.coins,
                  shade: TwColors.amber,
                ),
                AppStatTile(
                  // An unranked student is not "#0".
                  label: stats.rank == null
                      ? 'Unranked'
                      : 'of ${stats.totalStudents} in school',
                  value: stats.rank == null ? '—' : '#${stats.rank}',
                  icon: Icons.leaderboard_rounded,
                  shade: TwColors.blue,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (profile.heatmapDays.isNotEmpty) ...[
            StaggeredEntrance(
              index: 2,
              child: AppSectionCard(
                title: 'Activity',
                icon: Icons.grid_view_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HeatmapGrid(
                      days: profile.heatmapDays,
                      today: profile.heatmapToday,
                    ),
                    const SizedBox(height: 12),
                    const HeatmapLegend(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          StaggeredEntrance(
            index: 3,
            child: AppSectionCard(
              title: 'Badges',
              icon: Icons.workspace_premium_rounded,
              trailing: AppBadge('${profile.badges.length}', dense: true),
              child: profile.badges.isEmpty
                  ? const _EmptyNote('No badges earned yet.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < profile.badges.length; i++)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: i == profile.badges.length - 1 ? 0 : 8,
                            ),
                            child: PublicBadgeRow(badge: profile.badges[i]),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),

          StaggeredEntrance(
            index: 4,
            child: AppSectionCard(
              title: 'Recently solved',
              icon: Icons.check_circle_outline_rounded,
              padding: EdgeInsets.zero,
              child: profile.recentSolved.isEmpty
                  ? const _EmptyNote('No solved questions yet.')
                  : Column(
                      children: [
                        for (var i = 0; i < profile.recentSolved.length; i++)
                          RecentSolvedRow(
                            item: profile.recentSolved[i],
                            isLast: i == profile.recentSolved.length - 1,
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 26),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelMedium,
        ),
      );
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: const [
          AppSkeleton(height: 104, radius: AppTheme.radiusLg),
          SizedBox(height: 12),
          AppSkeleton(height: 150, radius: AppTheme.radiusLg),
          SizedBox(height: 12),
          AppSkeleton(height: 200, radius: AppTheme.radiusLg),
        ],
      );
}
