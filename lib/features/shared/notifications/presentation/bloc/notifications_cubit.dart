import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../../../../core/usecases/usecase.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/usecases/notification_usecases.dart';

/// The notification feed.
///
/// Port of `useNotifications` in `src/api/notification/use-notifications.ts`,
/// minus the infinite-scroll pages — the only consumer so far is the dashboard's
/// activity panel, which reads the first page and shows the top few rows.
class NotificationsCubit extends Cubit<RemoteState<NotificationFeed>> {
  NotificationsCubit({
    required ListNotificationsUseCase list,
    required MarkNotificationReadUseCase markRead,
  })  : _list = list,
        _markRead = markRead,
        super(const RemoteState());

  final ListNotificationsUseCase _list;
  final MarkNotificationReadUseCase _markRead;

  static const _pageSize = 20;

  Future<void> load({bool refresh = false}) async {
    if (isClosed) return;
    emit(state.copyWith(
      status: RemoteStatus.loading,
      isRefreshing: refresh,
      clearFailure: true,
    ));

    final result = await _list(const PageParams(limit: _pageSize));
    if (isClosed) return;

    result.fold(
      (failure) => emit(state.copyWith(
        status: RemoteStatus.failure,
        failure: failure,
        isRefreshing: false,
      )),
      (feed) => emit(RemoteState(status: RemoteStatus.success, data: feed)),
    );
  }

  /// Marks one row read, updating the list before the request resolves.
  ///
  /// The row is usually tapped to navigate away, so waiting for the round trip
  /// would leave it looking unread for the moment it is still on screen. A
  /// failure puts the previous feed back rather than leaving a lie behind.
  Future<void> markRead(String id) async {
    final feed = state.data;
    if (feed == null) return;

    final target = feed.items.where((n) => n.id == id).firstOrNull;
    if (target == null || target.isRead) return;

    emit(state.copyWith(
      data: feed.copyWith(
        items: [
          for (final item in feed.items)
            if (item.id == id)
              item.copyWith(
                isRead: true,
                readAt: DateTime.now().toUtc().toIso8601String(),
              )
            else
              item,
        ],
        // Never below zero: the server omits `unreadCount` on some queries, so
        // the local count can legitimately start at 0 with unread rows present.
        unreadCount: feed.unreadCount > 0 ? feed.unreadCount - 1 : 0,
      ),
    ));

    final result = await _markRead(IdParams(id));
    if (isClosed) return;
    result.fold((_) => emit(state.copyWith(data: feed)), (_) {});
  }
}
