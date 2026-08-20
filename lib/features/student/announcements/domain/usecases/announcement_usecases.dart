import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/network/api_response.dart';
import '../../../../../core/usecases/usecase.dart';
import '../entities/announcement.dart';
import '../repositories/announcement_repository.dart';

class ListAnnouncementsUseCase
    implements UseCase<Paginated<Announcement>, AnnouncementQueryParams> {
  const ListAnnouncementsUseCase(this._repository);

  final AnnouncementRepository _repository;

  @override
  Future<Either<Failure, Paginated<Announcement>>> call(
    AnnouncementQueryParams params,
  ) =>
      _repository.listFeed(
        query: params.query,
        type: params.type,
        page: params.page,
        limit: params.limit,
      );
}

class GetAnnouncementUseCase
    implements UseCase<AnnouncementDetail, IdParams> {
  const GetAnnouncementUseCase(this._repository);

  final AnnouncementRepository _repository;

  @override
  Future<Either<Failure, AnnouncementDetail>> call(IdParams params) =>
      _repository.getDetail(params.id);
}

class RegisterForAnnouncementUseCase
    implements UseCase<AnnouncementRegistration, IdParams> {
  const RegisterForAnnouncementUseCase(this._repository);

  final AnnouncementRepository _repository;

  @override
  Future<Either<Failure, AnnouncementRegistration>> call(IdParams params) =>
      _repository.register(params.id);
}

class CancelAnnouncementRegistrationUseCase
    implements UseCase<AnnouncementRegistration, IdParams> {
  const CancelAnnouncementRegistrationUseCase(this._repository);

  final AnnouncementRepository _repository;

  @override
  Future<Either<Failure, AnnouncementRegistration>> call(IdParams params) =>
      _repository.cancelRegistration(params.id);
}

class AnnouncementQueryParams extends Equatable {
  const AnnouncementQueryParams({
    this.query,
    this.type,
    this.page = 1,
    this.limit = AnnouncementMeta.pageSize,
  });

  /// Matches the title only, server-side.
  final String? query;
  final String? type;
  final int page;
  final int limit;

  /// The `clear*` flags exist because `??` cannot express "set this to null":
  /// passing `type: null` to drop the filter would silently keep the old value.
  AnnouncementQueryParams copyWith({
    int? page,
    String? query,
    String? type,
    bool clearQuery = false,
    bool clearType = false,
  }) =>
      AnnouncementQueryParams(
        query: clearQuery ? null : (query ?? this.query),
        type: clearType ? null : (type ?? this.type),
        page: page ?? this.page,
        limit: limit,
      );

  bool get hasFilters => activeFilterCount > 0;

  int get activeFilterCount =>
      ((query ?? '').isNotEmpty ? 1 : 0) + (type != null ? 1 : 0);

  @override
  List<Object?> get props => [query, type, page, limit];
}
