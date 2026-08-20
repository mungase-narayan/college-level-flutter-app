import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecases/usecase.dart';
import '../entities/app_notification.dart';
import '../repositories/notification_repository.dart';

class ListNotificationsUseCase
    implements UseCase<NotificationFeed, PageParams> {
  const ListNotificationsUseCase(this._repository);

  final NotificationRepository _repository;

  @override
  Future<Either<Failure, NotificationFeed>> call(PageParams params) =>
      _repository.list(page: params.page, limit: params.limit);
}

class MarkNotificationReadUseCase implements UseCase<void, IdParams> {
  const MarkNotificationReadUseCase(this._repository);

  final NotificationRepository _repository;

  @override
  Future<Either<Failure, void>> call(IdParams params) =>
      _repository.markRead(params.id);
}
