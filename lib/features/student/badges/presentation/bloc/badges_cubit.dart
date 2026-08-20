import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../../../../core/usecases/usecase.dart';
import '../../../leaderboard/domain/usecases/leaderboard_usecases.dart';
import '../../domain/entities/badge.dart';

/// The badge wall: one `GET /student/practice/badges`, no filters, no paging.
///
/// `T` is non-nullable, unlike the academic calendar's. The endpoint always
/// answers with `{ earned, catalog }` — an empty catalog is a legitimate
/// collection, not an absence — so there is no third "nothing published" case
/// to keep distinct from success.
///
/// The use case lives under the leaderboard feature because both endpoints sit
/// on `/student/practice` and are fetched together by the dashboard.
class BadgesCubit extends RemoteCubit<BadgeCollection> {
  BadgesCubit({required GetBadgesUseCase getBadges})
      : super(() => getBadges(const NoParams()));
}
