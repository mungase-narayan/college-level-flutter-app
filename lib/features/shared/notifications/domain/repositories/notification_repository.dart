import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../entities/app_notification.dart';

abstract class NotificationRepository {
  Future<Either<Failure, NotificationFeed>> list({
    int page,
    int limit,
    bool? unreadOnly,
  });

  Future<Either<Failure, void>> markRead(String id);
}
