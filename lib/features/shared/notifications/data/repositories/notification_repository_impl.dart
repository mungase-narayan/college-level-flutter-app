import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/error/guard.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/notification_service.dart';

class NotificationRepositoryImpl
    with RepositoryGuard
    implements NotificationRepository {
  const NotificationRepositoryImpl(this._service);

  final NotificationService _service;

  @override
  Future<Either<Failure, NotificationFeed>> list({
    int page = 1,
    int limit = 20,
    bool? unreadOnly,
  }) =>
      guard(
        () => _service.list(page: page, limit: limit, unreadOnly: unreadOnly),
      );

  @override
  Future<Either<Failure, void>> markRead(String id) =>
      guard(() => _service.markRead(id));
}
