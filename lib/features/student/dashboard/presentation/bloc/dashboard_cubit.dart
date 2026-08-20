import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../../../../core/error/failures.dart';
import '../../../../../core/usecases/usecase.dart';
import '../../../analytics/domain/entities/student_analytics.dart';
import '../../../analytics/domain/usecases/analytics_usecases.dart';
import '../../../badges/domain/entities/badge.dart';
import '../../../leaderboard/domain/entities/leaderboard.dart';
import '../../../leaderboard/domain/usecases/leaderboard_usecases.dart';
import '../../../practice/domain/entities/daily_challenge.dart';
import '../../../practice/domain/entities/practice_summary.dart';
import '../../../practice/domain/usecases/practice_usecases.dart';
import '../../../rating/domain/entities/contest_rating.dart';
import '../../../rating/domain/usecases/get_my_rating_usecase.dart';

/// Everything the student dashboard renders.
///
/// The panels below the fold ([rating], [semester], [leaderboardMe], [badges])
/// are nullable: the React dashboard renders each card independently and a
/// student with no contests or no current semester simply sees fewer cards.
class DashboardData extends Equatable {
  const DashboardData({
    required this.dailyChallenge,
    required this.summary,
    required this.analytics,
    required this.overview,
    this.rating,
    this.semester,
    this.leaderboardMe,
    this.badges,
  });

  final DailyChallenge dailyChallenge;
  final PracticeSummary summary;
  final PracticeAnalytics analytics;
  final AnalyticsOverview overview;
  final ContestRating? rating;
  final SemesterAnalytics? semester;
  final LeaderboardMe? leaderboardMe;
  final BadgeCollection? badges;

  @override
  List<Object?> get props => [
        dailyChallenge,
        summary,
        analytics,
        overview,
        rating,
        semester,
        leaderboardMe,
        badges,
      ];
}

/// Port of `src/pages/student/index.tsx`, which composes the daily-challenge
/// card, the rank/badge highlights, three stat cards, the activity heatmap, and
/// the practice analytics charts.
///
/// The React page fires all of these through react-query in parallel; doing
/// them sequentially here would multiply the time to first paint, so they are
/// started together and awaited afterwards.
class DashboardCubit extends Cubit<RemoteState<DashboardData>> {
  DashboardCubit({
    required GetDailyChallengeUseCase getDailyChallenge,
    required GetPracticeSummaryUseCase getSummary,
    required GetPracticeAnalyticsUseCase getAnalytics,
    required GetAnalyticsOverviewUseCase getOverview,
    required GetSemesterAnalyticsUseCase getSemester,
    required GetMyRatingUseCase getRating,
    required GetLeaderboardUseCase getLeaderboard,
    required GetBadgesUseCase getBadges,
  })  : _getDailyChallenge = getDailyChallenge,
        _getSummary = getSummary,
        _getAnalytics = getAnalytics,
        _getOverview = getOverview,
        _getSemester = getSemester,
        _getRating = getRating,
        _getLeaderboard = getLeaderboard,
        _getBadges = getBadges,
        super(const RemoteState());

  final GetDailyChallengeUseCase _getDailyChallenge;
  final GetPracticeSummaryUseCase _getSummary;
  final GetPracticeAnalyticsUseCase _getAnalytics;
  final GetAnalyticsOverviewUseCase _getOverview;
  final GetSemesterAnalyticsUseCase _getSemester;
  final GetMyRatingUseCase _getRating;
  final GetLeaderboardUseCase _getLeaderboard;
  final GetBadgesUseCase _getBadges;

  Future<void> load({bool refresh = false}) async {
    if (isClosed) return;
    emit(state.copyWith(
      status: RemoteStatus.loading,
      isRefreshing: refresh,
      clearFailure: true,
    ));

    // Start everything before awaiting anything so the requests overlap.
    final challengeFuture = _getDailyChallenge(const NoParams());
    final summaryFuture = _getSummary(const NoParams());
    final analyticsFuture = _getAnalytics(const NoParams());
    final overviewFuture = _getOverview(const NoParams());
    final ratingFuture = _getRating(const NoParams());
    final badgesFuture = _getBadges(const NoParams());
    // The React highlights card asks for a single row purely to read `me`.
    final leaderboardFuture = _getLeaderboard(
      const LeaderboardParams(
        scope: LeaderboardScope.school,
        period: LeaderboardPeriod.allTime,
        limit: 1,
      ),
    );

    final challenge = await challengeFuture;
    final summary = await summaryFuture;
    final analytics = await analyticsFuture;
    final overview = await overviewFuture;
    final rating = await ratingFuture;
    final badges = await badgesFuture;
    final leaderboard = await leaderboardFuture;
    if (isClosed) return;

    // The four core sources decide success; the optional panels degrade to an
    // absent card rather than taking the whole screen down.
    final failure = challenge.fold((f) => f, (_) => null) ??
        summary.fold((f) => f, (_) => null) ??
        analytics.fold((f) => f, (_) => null) ??
        overview.fold((f) => f, (_) => null);

    if (failure != null) {
      emit(state.copyWith(
        status: RemoteStatus.failure,
        failure: failure,
        isRefreshing: false,
      ));
      return;
    }

    final overviewData = _valueOf(overview)!;
    final semesterId = overviewData.defaultSemesterId;
    final semester = semesterId == null
        ? null
        : _valueOf(await _getSemester(IdParams(semesterId)));
    if (isClosed) return;

    emit(
      RemoteState(
        status: RemoteStatus.success,
        data: DashboardData(
          dailyChallenge: _valueOf(challenge)!,
          summary: _valueOf(summary)!,
          analytics: _valueOf(analytics)!,
          overview: overviewData,
          rating: _valueOf(rating),
          semester: semester,
          leaderboardMe: _valueOf(leaderboard)?.me,
          badges: _valueOf(badges),
        ),
      ),
    );
  }

  /// The right side of an `Either`, or null when it failed.
  T? _valueOf<T>(Either<Failure, T> result) => result.fold((_) => null, (v) => v);
}
