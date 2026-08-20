import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_colors.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../analytics/domain/entities/student_analytics.dart';
import '../../../../shared/auth/presentation/bloc/auth/auth_bloc.dart';
import '../../../badges/domain/entities/badge.dart';
import '../../../leaderboard/domain/entities/leaderboard.dart';
import '../../../rating/domain/entities/contest_rating.dart';
import '../../../../shared/shell/presentation/pages/app_shell.dart';
import '../../../../shared/shell/presentation/widgets/student_nav.dart';
import '../../../practice/domain/entities/daily_challenge.dart';
import '../bloc/dashboard_cubit.dart';
import '../widgets/today_sessions_card.dart';
import '../widgets/practice_analytics_section.dart';

/// Port of `src/pages/student/index.tsx` — the student dashboard.
///
/// Stacks the daily-challenge card, the practice highlights, the practice
/// analytics tiles, and the GitHub-style activity heatmap, in that order.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    context.read<DashboardCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DashboardCubit>();
    final auth = context.watch<AuthBloc>().state;

    // The shell owns the app bar; this contributes body only.
    return ShellScaffold(
      child: RefreshIndicator(
          onRefresh: () => cubit.load(refresh: true),
          child: RemoteView<DashboardCubit, DashboardData>(
            onRetry: cubit.load,
            loading: const Padding(
              padding: EdgeInsets.all(16),
              child: AppListSkeleton(rows: 4, lines: 3),
            ),
            builder: (context, data) => RefreshableScroll(
              onRefresh: () => cubit.load(refresh: true),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _WelcomeHeader(name: auth.user?.displayName),
                  const SizedBox(height: 14),
                  _DailyChallengeCard(challenge: data.dailyChallenge),
                  const SizedBox(height: 12),

                  // Port of `TodaySessionsCard`. On the web this is the
                  // dashboard's right-hand column, alongside the challenge;
                  // stacked, that puts it here.
                  const TodaySessionsCard(),
                  const SizedBox(height: 12),

                  // Port of `DashboardHighlights` — rank and badges.
                  _Highlights(me: data.leaderboardMe, badges: data.badges),
                  const SizedBox(height: 12),

                  // Port of `DashboardStats` — rating, assignments, quizzes.
                  _DashboardStats(rating: data.rating, semester: data.semester),
                  const SizedBox(height: 12),

                  // Practice highlights.
                  AppStatGrid(
                    tiles: [
                      AppStatTile(
                        label: 'Solved',
                        value: Fmt.number(data.summary.questionsSolved),
                        caption: 'of ${Fmt.number(data.summary.totalQuestionsAvailable)}',
                        icon: Icons.check_circle_outline_rounded,
                        shade: TwColors.emerald,
                      ),
                      AppStatTile(
                        label: 'Accuracy',
                        value: data.summary.overallAccuracy == null
                            ? '—'
                            : '${data.summary.overallAccuracy}%',
                        caption: '${Fmt.number(data.summary.correctAnswers)} correct',
                        icon: Icons.percent_rounded,
                        shade: TwColors.blue,
                      ),
                      AppStatTile(
                        label: 'Coins',
                        value: Fmt.number(data.summary.totalPoints),
                        icon: AppIcons.coins,
                        shade: TwColors.amber,
                        onTap: () => context.push(StudentRoutes.wallet),
                      ),
                      AppStatTile(
                        label: 'Current streak',
                        value: '${data.analytics.heatmap.currentStreak}',
                        caption: 'days',
                        icon: Icons.local_fire_department_outlined,
                        shade: TwColors.orange,
                      ),
                    ],
                  ),

                  if (data.summary.pendingReviews > 0) ...[
                    const SizedBox(height: 12),
                    _PendingReviewNotice(count: data.summary.pendingReviews),
                  ],

                  const SizedBox(height: 12),
                  AppSectionCard(
                    title: 'Activity',
                    subtitle: 'Your practice over the past year',
                    icon: Icons.grid_view_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        HeatmapGrid(days: data.analytics.heatmap.days),
                        const SizedBox(height: 12),
                        // Swatches sized to the grid's cells so the key reads as
                        // the same material as the grid it describes.
                        const HeatmapLegend(),
                      ],
                    ),
                  ),

                  if (data.analytics.difficulty.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    AppSectionCard(
                      title: 'By difficulty',
                      icon: Icons.speed_rounded,
                      child: PracticeDifficultyGrid(
                        difficulty: data.analytics.difficulty,
                      ),
                    ),
                  ],

                  if (data.analytics.subjects.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    AppSectionCard(
                      title: 'By subject',
                      icon: Icons.menu_book_outlined,
                      child: Column(
                        children: [
                          for (final row in data.analytics.subjects.take(6))
                            _BreakdownRow(
                              label: row.label,
                              solved: row.solved,
                              attempts: row.attempts,
                            ),
                        ],
                      ),
                    ),
                  ],

                  // Port of `PracticeAnalytics` — the four chart panels.
                  const SizedBox(height: 12),
                  PracticeAnalyticsSection(analytics: data.analytics),
                ],
              ),
            ),
          ),
        ),
    );
  }
}

/// Port of `components/dashboard-highlights.tsx` — the leaderboard rank card
/// and the earned-badges card, side by side.
class _Highlights extends StatelessWidget {
  const _Highlights({this.me, this.badges});

  final LeaderboardMe? me;
  final BadgeCollection? badges;

  @override
  Widget build(BuildContext context) {
    // React is `grid-cols-1 sm:grid-cols-2` — a phone stacks these. Stacking
    // also keeps the cards inside a bounded box; a Row with
    // `CrossAxisAlignment.stretch` inside a scroll view has no height to
    // stretch to and fails to lay out.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RankCard(me: me),
        const SizedBox(height: 12),
        _BadgesCard(badges: badges),
      ],
    );
  }
}

class _RankCard extends StatelessWidget {
  const _RankCard({this.me});

  final LeaderboardMe? me;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return AppCard(
      onTap: () => context.push(StudentRoutes.leaderboard),
      color: scheme.primary.withValues(alpha: 0.07),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.leaderboard_rounded, size: 17, color: scheme.primary),
              const SizedBox(width: 7),
              Text('Rank', style: theme.textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            me == null ? 'Unranked' : '#${me!.rank}',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.primary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            me == null
                ? 'Solve questions to get ranked'
                : 'School · ${Fmt.number(me!.points)} pts',
            style: theme.textTheme.labelSmall,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

class _BadgesCard extends StatelessWidget {
  const _BadgesCard({this.badges});

  final BadgeCollection? badges;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final amber = tokens.warning;

    // De-duplicated by badgeKey, exactly as the React card does before
    // rendering its tier chips.
    final earned = badges?.earnedByKey.values.toList(growable: false) ?? const [];
    final shown = earned.take(6).toList(growable: false);
    final overflow = earned.length - shown.length;

    return AppCard(
      onTap: () => context.push(StudentRoutes.badges),
      color: amber.background,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_rounded, size: 17, color: amber.foreground),
              const SizedBox(width: 7),
              Text('Badges', style: theme.textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${earned.length}',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: amber.foreground,
            ),
          ),
          const SizedBox(height: 6),
          if (earned.isEmpty)
            Text('Keep practicing to earn badges', style: theme.textTheme.labelSmall)
          else
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final badge in shown)
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: BadgeTier.gradient(badge.tier),
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                if (overflow > 0)
                  Text('+$overflow', style: theme.textTheme.labelSmall),
              ],
            ),
        ],
      ),
    );
  }
}

/// Port of `components/dashboard-stats.tsx` — contest rating, total
/// assignments, and total quizzes, each linking to its own tab.
class _DashboardStats extends StatelessWidget {
  const _DashboardStats({this.rating, this.semester});

  final ContestRating? rating;
  final SemesterAnalytics? semester;

  @override
  Widget build(BuildContext context) {
    /// "{attempted} attempted · {pending} pending".
    String hint(CategoryStats? stats) => stats == null
        ? '—'
        : '${stats.attempted} attempted · ${stats.pending} pending';

    // React is `grid-cols-1 sm:grid-cols-3` — stacked full width on a phone.
    return AppStatGrid(
      columns: 1,
      tiles: [
        AppStatTile(
          label: 'Contest rating',
          value: rating == null ? '—' : '${rating!.rating}',
          caption: rating == null
              ? 'Play a contest to get rated'
              : '${rating!.tier} · ${rating!.contestsPlayed} contest'
                  '${rating!.contestsPlayed == 1 ? '' : 's'}',
          icon: Icons.trending_up_rounded,
          shade: TwColors.pink,
          onTap: () => context.push(StudentRoutes.rating),
        ),
        AppStatTile(
          label: 'Assignments',
          value: '${semester?.assignment.total ?? 0}',
          caption: hint(semester?.assignment),
          icon: Icons.assignment_outlined,
          shade: TwColors.blue,
          onTap: () => context.push(StudentRoutes.assignments),
        ),
        AppStatTile(
          label: 'Quizzes',
          value: '${semester?.quiz.total ?? 0}',
          caption: hint(semester?.quiz),
          icon: Icons.checklist_rounded,
          shade: TwColors.emerald,
          onTap: () => context.push(StudentRoutes.quiz),
        ),
      ],
    );
  }
}

/// The greeting that used to live in this page's own app bar, now that the
/// shell header shows the tab name instead.
class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Welcome back', style: theme.textTheme.labelSmall),
        Text(
          name ?? 'Student',
          style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Port of the React `DailyChallengeCard` — the streak hook at the top of the
/// dashboard.
class _DailyChallengeCard extends StatelessWidget {
  const _DailyChallengeCard({required this.challenge});

  final DailyChallenge challenge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final scheme = tokens.scheme;
    final completion = challenge.completion;

    return AppCard(
      onTap: () => context.push('/student/daily-challenge'),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [TwColors.orange.s500, TwColors.amber.s500],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  size: 21,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily Challenge', style: theme.textTheme.titleSmall),
                    Text(
                      challenge.set?.title ??
                          (challenge.available
                              ? 'Ready to solve'
                              : 'No challenge posted today'),
                      style: theme.textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (challenge.isCompleted)
                AppBadge(
                  'Done',
                  shade: TwColors.emerald,
                  icon: Icons.check_rounded,
                  dense: true,
                )
              else if (!challenge.canSolve && challenge.available)
                AppBadge('Closed', shade: TwColors.slate, dense: true),
            ],
          ),

          if (completion != null && completion.totalQuestions > 0) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      // Attempted, not solved — the same measure as the "Done"
                      // badge above it, which the server sets once every
                      // question has been answered.
                      value: completion.attemptedFraction,
                      minHeight: 6,
                      backgroundColor: scheme.muted,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${completion.attemptedCount}/${completion.totalQuestions}',
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),
          Row(
            children: [
              _MiniStat(
                icon: Icons.local_fire_department_outlined,
                label: 'Streak',
                value: '${challenge.streak.currentStreak}d',
              ),
              const SizedBox(width: 18),
              _MiniStat(
                icon: Icons.stars_rounded,
                label: 'Points',
                value: Fmt.number(challenge.streak.totalPoints),
              ),
              const SizedBox(width: 18),
              _MiniStat(
                icon: Icons.event_available_outlined,
                label: 'Completed',
                value: '${challenge.streak.challengesCompleted}',
              ),
              if (challenge.availableTickets > 0) ...[
                const SizedBox(width: 18),
                _MiniStat(
                  icon: Icons.confirmation_number_outlined,
                  label: 'Tickets',
                  value: '${challenge.availableTickets}',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: scheme.mutedForeground),
        const SizedBox(width: 5),
        Text(value, style: theme.textTheme.labelMedium),
        const SizedBox(width: 3),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

/// Subjective and coding attempts sit in a teacher queue before they score, so
/// the dashboard says so rather than letting the accuracy tile look wrong.
class _PendingReviewNotice extends StatelessWidget {
  const _PendingReviewNotice({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = context.tokens.warning;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_bottom_rounded, size: 17, color: tone.foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count submission${count == 1 ? '' : 's'} awaiting teacher review.',
              style: theme.textTheme.bodySmall?.copyWith(color: tone.foreground),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.solved,
    required this.attempts,
  });

  final String label;
  final int solved;
  final int attempts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final fraction = attempts == 0 ? 0.0 : (solved / attempts).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label.isEmpty ? 'Unlabelled' : label,
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.foreground),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('$solved / $attempts', style: theme.textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 5,
              backgroundColor: scheme.muted,
            ),
          ),
        ],
      ),
    );
  }
}
