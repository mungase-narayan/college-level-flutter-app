import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../../../../core/usecases/usecase.dart';
import '../../domain/entities/teacher_dashboard.dart';
import '../../domain/usecases/teacher_usecases.dart';

/// Port of `useTeacherDashboard` in `src/api/teacher/use-teacher-dashboard.ts`.
///
/// One endpoint drives the whole screen, so this is the single-loader case —
/// with one addition. Each session's `upcoming | live | completed` badge is
/// computed by the server in the school's timezone, and the payload carries no
/// timestamps, so the client has nothing to recompute from. The web app never
/// refetches, which leaves "Upcoming" showing over a class that started ten
/// minutes ago; here a slow poll keeps the badges honest while the screen is up.
class TeacherDashboardCubit extends Cubit<RemoteState<TeacherDashboard>> {
  TeacherDashboardCubit({required GetTeacherDashboardUseCase getDashboard})
      : _getDashboard = getDashboard,
        super(const RemoteState());

  final GetTeacherDashboardUseCase _getDashboard;

  /// Slow enough to be invisible on the wire, fast enough that a badge is never
  /// more than a minute stale.
  static const refreshInterval = Duration(minutes: 1);

  Timer? _timer;

  Future<void> load({bool refresh = false}) async {
    if (isClosed) return;
    emit(state.copyWith(
      status: RemoteStatus.loading,
      isRefreshing: refresh,
      clearFailure: true,
    ));

    final result = await _getDashboard(const NoParams());
    if (isClosed) return;

    result.fold(
      (failure) {
        // Stop polling into a failing endpoint; Retry re-arms it.
        _stopPolling();
        emit(state.copyWith(
          status: RemoteStatus.failure,
          failure: failure,
          isRefreshing: false,
        ));
      },
      (dashboard) {
        emit(RemoteState(status: RemoteStatus.success, data: dashboard));
        _syncPolling(dashboard);
      },
    );
  }

  /// Polls only while a session could still change on its own. Once the last
  /// one is `completed` nothing more happens today, so the timer is dropped.
  void _syncPolling(TeacherDashboard dashboard) {
    if (!dashboard.hasPendingSessions) {
      _stopPolling();
      return;
    }
    _timer ??= Timer.periodic(
      refreshInterval,
      (_) => load(refresh: true),
    );
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> close() {
    _stopPolling();
    return super.close();
  }
}
