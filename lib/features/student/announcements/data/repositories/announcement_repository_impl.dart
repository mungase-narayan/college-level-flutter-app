import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/error/guard.dart';
import '../../../../../core/network/api_response.dart';
import '../../domain/entities/announcement.dart';
import '../../domain/repositories/announcement_repository.dart';
import '../datasources/announcement_service.dart';

class AnnouncementRepositoryImpl
    with RepositoryGuard
    implements AnnouncementRepository {
  const AnnouncementRepositoryImpl(this._service);

  final AnnouncementService _service;

  @override
  Future<Either<Failure, Paginated<Announcement>>> listFeed({
    String? query,
    String? type,
    int page = 1,
    int limit = AnnouncementMeta.pageSize,
  }) =>
      guard(() async {
        final result = await _service.listFeed(
          query: query,
          type: type,
          page: page,
          limit: limit,
        );
        return Paginated<Announcement>(
          items: result.items,
          pagination: result.pagination,
        );
      });

  @override
  Future<Either<Failure, AnnouncementDetail>> getDetail(String id) =>
      guard(() => _service.getDetail(id));

  @override
  Future<Either<Failure, AnnouncementRegistration>> register(String id) =>
      guard(() => _service.register(id));

  @override
  Future<Either<Failure, AnnouncementRegistration>> cancelRegistration(
    String id,
  ) =>
      guard(() => _service.cancelRegistration(id));
}
