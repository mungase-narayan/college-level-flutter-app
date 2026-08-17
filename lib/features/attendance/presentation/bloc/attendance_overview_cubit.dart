import '../../../../core/common/bloc/remote_cubit.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/attendance.dart';
import '../../domain/usecases/attendance_usecases.dart';

/// The stat tiles and the course-wise breakdown.
///
/// Its own cubit, separate from the sessions list, for the reason the dashboard
/// gives for `TodaySessionsCubit`: this reads a different endpoint, and a
/// failure here must not take the rest of the screen down with it. It also has
/// nothing to re-fetch when a filter changes — `/analytics/overall` aggregates
/// every enrolled course and returns the same numbers whatever the student is
/// filtering the session list by.
///
/// It doubles as the source of the course filter's options: the payload already
/// carries the course list, so the page reads it from here rather than spending
/// a second request on it.
class AttendanceOverviewCubit extends RemoteCubit<AttendanceOverview> {
  AttendanceOverviewCubit({required GetOverallAttendanceUseCase getOverall})
      : super(() => getOverall(const NoParams()));
}
