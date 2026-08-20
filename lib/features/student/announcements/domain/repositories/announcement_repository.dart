import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/network/api_response.dart';
import '../entities/announcement.dart';

abstract class AnnouncementRepository {
  Future<Either<Failure, Paginated<Announcement>>> listFeed({
    String? query,
    String? type,
    int page,
    int limit,
  });

  Future<Either<Failure, AnnouncementDetail>> getDetail(String id);

  Future<Either<Failure, AnnouncementRegistration>> register(String id);

  Future<Either<Failure, AnnouncementRegistration>> cancelRegistration(
    String id,
  );
}
